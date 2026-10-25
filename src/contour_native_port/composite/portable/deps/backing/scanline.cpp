#include "scanline.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <new>
#include <numeric>
#include <vector>
namespace {
constexpr size_t kMaxSegments = 65536;
constexpr uint64_t kMaxWork = 100000000;
struct Segment {
  double ax, ay, bx, by, dx, dy, minY, maxY;
};
struct Context {
  std::vector<Segment> segments;
  std::vector<uint32_t> start_order;
  int32_t rule;
};
struct Crossing {
  double x;
  int wind;
  uint32_t id;
};
struct BudgetExceeded {};
struct Cancelled {};
}
extern "C" void *sc_create(const double *input, int32_t count, int32_t rule, int32_t *status) {
  if (status)
    *status = 1;
  if (count < 0 || (count > 0 && !input) || (rule < 0 || rule > 3))
    return nullptr;
  if (static_cast<size_t>(count) > kMaxSegments) {
    if (status)
      *status = 3;
    return nullptr;
  }
  Context *ctx = nullptr;
  try {
    ctx = new Context;
    ctx->rule = rule;
    ctx->segments.reserve(count);
    for (int32_t i = 0; i < count; i++) {
      double ax = input[4 * i], ay = input[4 * i + 1], bx = input[4 * i + 2], by = input[4 * i + 3];
      if (!std::isfinite(ax) || !std::isfinite(ay) || !std::isfinite(bx) || !std::isfinite(by) ||
          std::max({std::abs(ax), std::abs(ay), std::abs(bx), std::abs(by)}) > 1e7) {
        delete ctx;
        return nullptr;
      }
      if (ax == bx && ay == by)
        continue;
      ctx->segments.push_back(
          {ax, ay, bx, by, bx - ax, by - ay, std::min(ay, by), std::max(ay, by)});
    }
    ctx->start_order.resize(ctx->segments.size());
    std::iota(ctx->start_order.begin(), ctx->start_order.end(), 0);
    std::sort(ctx->start_order.begin(), ctx->start_order.end(), [&](uint32_t a, uint32_t b) {
      return ctx->segments[a].minY < ctx->segments[b].minY;
    });
    if (status)
      *status = 0;
    return ctx;
  } catch (const std::bad_alloc &) {
    delete ctx;
    if (status)
      *status = 2;
    return nullptr;
  } catch (...) {
    delete ctx;
    return nullptr;
  }
}
extern "C" void sc_destroy(void *pointer) {
  delete static_cast<Context *>(pointer);
}
extern "C" uint64_t sc_owned_context_bytes(const void *pointer) {
  if (!pointer)
    return 0;
  const auto &ctx = *static_cast<const Context *>(pointer);
  return sizeof(Context) + ctx.segments.capacity() * sizeof(Segment) +
         ctx.start_order.capacity() * sizeof(uint32_t);
}
extern "C" int32_t sc_render(const void *pointer, int32_t width, int32_t height, double radius,
                             int32_t aa, uint8_t *output, sc_cancel_fn cancel, void *user,
                             sc_stats *result) {
  // Rasterize already-expanded filled contours. The radius parameter remains
  // zero because offset generation belongs to the preceding geometry stage.
  if (!pointer || !output || width <= 0 || height <= 0 || radius != 0 ||
      (aa != 1 && aa != 8 && aa != 16 && aa != 32 && aa != 64))
    return 1;
  if (width > 2048 || height > 2048 || static_cast<uint64_t>(width) * height > 1024 * 1024)
    return 3;
  const auto &ctx = *static_cast<const Context *>(pointer);
  sc_stats stats{};
  auto check = [&]() {
    if (stats.segment_visits + stats.sort_comparisons + stats.pixel_writes > kMaxWork)
      throw BudgetExceeded{};
    if (cancel && cancel(user))
      throw Cancelled{};
  };
  try {
    std::vector<uint32_t> active;
    active.reserve(ctx.segments.size());
    size_t next = 0;
    std::vector<Crossing> crossings;
    crossings.reserve(ctx.segments.size());
    std::vector<double> edge(width, 0), difference(width + 1, 0);
    stats.scratch_bytes = sizeof(active) + sizeof(crossings) + sizeof(edge) + sizeof(difference) +
                          active.capacity() * sizeof(uint32_t) +
                          crossings.capacity() * sizeof(Crossing) +
                          (edge.capacity() + difference.capacity()) * sizeof(double);
    for (int y = 0; y < height; y++) {
      check();
      std::fill(edge.begin(), edge.end(), 0);
      std::fill(difference.begin(), difference.end(), 0);
      for (int sy = 0; sy < aa; sy++) {
        double py = y + (sy + .5) / aa;
        stats.subrows++;
        while (next < ctx.start_order.size() && ctx.segments[ctx.start_order[next]].minY <= py) {
          active.push_back(ctx.start_order[next++]);
          if ((next & 255) == 0)
            check();
        }
        crossings.clear();
        size_t retained = 0;
        for (size_t at = 0; at < active.size(); at++) {
          const uint32_t id = active[at];
          const auto &s = ctx.segments[id];
          if (s.maxY <= py)
            continue;
          active[retained++] = id;
          stats.segment_visits++;
          if ((s.ay <= py && s.by > py) || (s.by <= py && s.ay > py))
            crossings.push_back({s.ax + (py - s.ay) * s.dx / s.dy, s.by > s.ay ? 1 : -1, id});
          if ((at & 255) == 255)
            check();
        }
        active.resize(retained);
        stats.max_active = std::max<uint64_t>(stats.max_active, active.size());
        stats.crossings += crossings.size();
        auto less = [&](const Crossing &a, const Crossing &b) {
          stats.sort_comparisons++;
          if ((stats.sort_comparisons & 1023) == 0)
            check();
          return a.x < b.x;
        };
        const size_t move_limit = std::max<size_t>(32, crossings.size() * 4);
        size_t moves = 0;
        bool fallback = false;
        for (size_t i = 1; i < crossings.size(); ++i) {
          Crossing value = crossings[i];
          size_t j = i;
          while (j && less(value, crossings[j - 1])) {
            crossings[j] = crossings[j - 1];
            --j;
            if (++moves > move_limit) {
              fallback = true;
              break;
            }
          }
          crossings[j] = value;
          if (fallback)
            break;
        }
        if (fallback)
          std::sort(crossings.begin(), crossings.end(), less);
        active.resize(crossings.size());
        for (size_t i = 0; i < crossings.size(); ++i)
          active[i] = crossings[i].id;
        check();
        auto emit = [&](double a, double b) {
          a = std::max(0., a);
          b = std::min(static_cast<double>(width), b);
          if (b <= a)
            return;
          stats.intervals++;
          int first = static_cast<int>(std::floor(a)), last = static_cast<int>(std::floor(b));
          if (first == last) {
            if (first < width)
              edge[first] += b - a;
            return;
          }
          if (first < width)
            edge[first] += first + 1 - a;
          if (last < width)
            edge[last] += b - last;
          int fullFirst = first + 1, fullEnd = last;
          if (fullEnd > fullFirst) {
            difference[fullFirst] += 1;
            difference[fullEnd] -= 1;
          }
        };
        int winding = 0;
        bool inside = false;
        double start = 0;
        for (size_t at = 0; at < crossings.size();) {
          size_t end = at + 1;
          int delta = crossings[at].wind;
          while (end < crossings.size() && crossings[end].x == crossings[at].x) {
            delta += crossings[end].wind;
            end++;
          }
          bool was = inside;
          if (ctx.rule != 0)
            winding += delta;
          else
            winding ^= static_cast<int>((end - at) & 1);
          inside = ctx.rule == 2 ? winding < 0 : ctx.rule == 3 ? winding > 0 : winding != 0;
          if (!was && inside)
            start = crossings[at].x;
          else if (was && !inside)
            emit(start, crossings[at].x);
          at = end;
          if ((at & 255) == 0)
            check();
        }
        check();
      }
      if (stats.segment_visits + stats.sort_comparisons + stats.pixel_writes +
              static_cast<uint64_t>(width) >
          kMaxWork)
        throw BudgetExceeded{};
      double full = 0;
      for (int x = 0; x < width; x++) {
        full += difference[x];
        double coverage = std::clamp((full + edge[x]) / aa, 0., 1.);
        output[static_cast<size_t>(y) * width + x] =
            static_cast<uint8_t>(std::lround(coverage * 255));
      }
      stats.pixel_writes += width;
    }
    if (result)
      *result = stats;
    return 0;
  } catch (const BudgetExceeded &) {
    if (result)
      *result = stats;
    return 3;
  } catch (const Cancelled &) {
    if (result)
      *result = stats;
    return 4;
  } catch (const std::bad_alloc &) {
    if (result)
      *result = stats;
    return 2;
  } catch (...) {
    if (result)
      *result = stats;
    return 1;
  }
}
