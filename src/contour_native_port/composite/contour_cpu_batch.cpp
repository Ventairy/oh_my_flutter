#include "contour_cpu_batch.h"
#include <algorithm>
#include <atomic>
#include <cstring>
#include <new>
#include <limits>
#include <thread>
#include <time.h>
namespace contour_cpu {
namespace {
int64_t now(clockid_t id) {
  timespec t{};
  clock_gettime(id, &t);
  return int64_t(t.tv_sec) * 1000000000 + t.tv_nsec;
}
uint64_t scratch(const contour_generic::Scratch &s) {
  uint64_t n = s.source_alpha.capacity() + s.curves.capacity() * sizeof(std::vector<double>) +
               s.backing.alpha.capacity() +
               s.compositor.temporary.capacity() + s.compositor.blurred.capacity() +
               s.compositor.ring.capacity() * sizeof(uint32_t);
  for (const auto &v : s.curves)
    n += v.capacity() * sizeof(double);
  return n;
}
bool equalStyle(const Tile &a, const Tile &b) {
  if (a.width != b.width || a.height != b.height || a.source_ratio != b.source_ratio ||
      a.output_ratio != b.output_ratio || a.amount != b.amount ||
      a.contour_argb != b.contour_argb || a.shadow_count != b.shadow_count || a.shadow_count > 4)
    return false;
  for (size_t i = 0; i < a.shadow_count; i++) {
    const auto &x = a.shadows[i];
    const auto &y = b.shadows[i];
    if (x.sigma != y.sigma || x.dx != y.dx || x.dy != y.dy || x.argb != y.argb)
      return false;
  }
  return true;
}
void mixHash(uint64_t &hash, uint64_t value) {
  hash ^= value + 0x9e3779b97f4a7c15ULL + (hash << 6) + (hash >> 2);
}
uint64_t bits(double value) {
  uint64_t result;
  std::memcpy(&result, &value, sizeof(result));
  return result;
}
bool alphaHash(const Request &r, const Tile &t, uint64_t &hash, contour_generic::CancelFn cancel,
               void *user) {
  hash = 0xcbf29ce484222325ULL;
  mixHash(hash, t.width);
  mixHash(hash, t.height);
  mixHash(hash, bits(t.source_ratio));
  mixHash(hash, bits(t.output_ratio));
  mixHash(hash, bits(t.amount));
  mixHash(hash, t.contour_argb);
  mixHash(hash, t.shadow_count);
  for (size_t i = 0; i < t.shadow_count; i++) {
    const auto &s = t.shadows[i];
    mixHash(hash, bits(s.sigma));
    mixHash(hash, bits(s.dx));
    mixHash(hash, bits(s.dy));
    mixHash(hash, s.argb);
  }
  for (uint32_t y = 0; y < t.height; y++) {
    if ((y & 31) == 0 && cancel && cancel(user))
      return false;
    const auto *row = r.rgba + size_t(t.y + y) * r.stride + size_t(t.x) * 4;
    for (uint32_t x = 0; x < t.width; x++)
      hash = (hash ^ row[size_t(x) * 4 + 3]) * 1099511628211ULL;
  }
  return true;
}
bool equalAlpha(const Request &r, const Tile &a, const Tile &b) {
  for (uint32_t y = 0; y < a.height; y++) {
    const auto *x = r.rgba + size_t(a.y + y) * r.stride + size_t(a.x) * 4;
    const auto *z = r.rgba + size_t(b.y + y) * r.stride + size_t(b.x) * 4;
    for (uint32_t p = 0; p < a.width; p++)
      if (x[size_t(p) * 4 + 3] != z[size_t(p) * 4 + 3])
        return false;
  }
  return true;
}
}
contour_generic::Status render(const Request &r, Output &out, contour_generic::CancelFn cancel,
                               void *user) {
  out = {};
  const auto start = now(CLOCK_MONOTONIC);
  auto finish = [&](contour_generic::Status s) {
    out.status = s;
    out.metrics.wall_ns = now(CLOCK_MONOTONIC) - start;
    return s;
  };
  try {
    if (!r.rgba || !r.tiles || !r.width || !r.height || r.width > 4096 || r.height > 4096 ||
        r.count < 1 || r.count > 40 || r.stride < size_t(r.width) * 4 ||
        r.stride > std::numeric_limits<size_t>::max() / r.height ||
        size_t(r.height - 1) * r.stride + size_t(r.width) * 4 > r.length || r.workers < 1 ||
        r.workers > 2 || r.atlas_width < 1 || r.atlas_width > 4096 || r.gutter > 8 ||
        r.allocation_limit > 64ULL * 1024 * 1024 || r.allocation_limit < r.length + 1024) {
      out.error = "invalid batch admission";
      return finish(contour_generic::Status::invalid);
    }
    const uint64_t local_limit = (r.allocation_limit - r.length) / r.workers;
    std::array<size_t, 40> representative{}, unique{};
    std::array<uint64_t, 40> hashes{};
    size_t unique_count = 0;
    const auto dedup_start = now(CLOCK_THREAD_CPUTIME_ID);
    for (size_t i = 0; i < r.count; i++) {
      representative[i] = i;
      const auto &t = r.tiles[i];
      if (t.x > r.width || t.y > r.height || t.width > r.width - t.x ||
          t.height > r.height - t.y || !t.width || !t.height) {
        out.error = "tile outside source atlas";
        return finish(contour_generic::Status::invalid);
      }
      if (cancel && cancel(user))
        return finish(contour_generic::Status::cancelled);
      if (t.shadow_count <= 4 && t.width <= 2048 && t.height <= 2048 &&
          uint64_t(t.width) * t.height <= 1024 * 1024) {
        if (!alphaHash(r, t, hashes[i], cancel, user))
          return finish(contour_generic::Status::cancelled);
        for (size_t j = 0; j < unique_count; j++) {
          const auto candidate = unique[j];
          if (hashes[i] == hashes[candidate] && equalStyle(t, r.tiles[candidate]) &&
              equalAlpha(r, t, r.tiles[candidate])) {
            representative[i] = candidate;
            break;
          }
        }
      }
      if (representative[i] == i)
        unique[unique_count++] = i;
    }
    out.metrics.dedup_cpu_ns = now(CLOCK_THREAD_CPUTIME_ID) - dedup_start;
    out.metrics.cpu_sum_ns += out.metrics.dedup_cpu_ns;
    std::vector<contour_generic::Output> tiles(r.count);
    std::atomic<size_t> next{0};
    std::atomic<uint32_t> active{0}, peak{0};
    std::atomic<bool> lane_failed{false};
    std::array<Metrics, 2> m{};
    auto worker = [&](uint32_t lane) {
      const auto began = now(CLOCK_THREAD_CPUTIME_ID);
      contour_generic::Scratch s;
      uint64_t retained = 0;
      try {
        while (true) {
          const size_t work = next.fetch_add(1);
          if (work >= unique_count)
            break;
          const size_t i = unique[work];
          const auto &t = r.tiles[i];
          if (t.x > r.width || t.y > r.height || t.width > r.width - t.x ||
              t.height > r.height - t.y || !t.width || !t.height) {
            tiles[i].error = "tile outside source atlas";
            tiles[i].status = contour_generic::Status::invalid;
            continue;
          }
          if (cancel && cancel(user)) {
            tiles[i].status = contour_generic::Status::cancelled;
            continue;
          }
          const auto n = active.fetch_add(1) + 1;
          auto p = peak.load();
          while (p < n && !peak.compare_exchange_weak(p, n)) {
          }
          const size_t offset = size_t(t.y) * r.stride + size_t(t.x) * 4;
          contour_generic::Request q;
          q.source = r.rgba + offset;
          q.source_length = r.length - offset;
          q.source_stride = r.stride;
          q.rgba = true;
          q.width = t.width;
          q.height = t.height;
          q.source_ratio = t.source_ratio;
          q.output_ratio = t.output_ratio;
          q.amount = t.amount;
          q.contour_argb = t.contour_argb;
          q.shadows = t.shadows.data();
          q.shadow_count = t.shadow_count;
          q.allocation_limit = retained < local_limit ? local_limit - retained : 0;
          q.trace_limit = std::min<uint64_t>(3 * 1024 * 1024, q.allocation_limit);
          q.output_pixel_limit = 1024 * 1024;
          auto &o = tiles[i];
          contour_generic::render(q, o, s, cancel, user);
          m[lane].trace_cpu_ns += o.metrics.trace_cpu_ns;
          m[lane].backing_cpu_ns += o.metrics.backing_cpu_ns;
          m[lane].composition_cpu_ns += o.metrics.composition_cpu_ns;
          if (o.status == contour_generic::Status::empty) {
            const auto live = scratch(s);
            if (retained > local_limit || live > local_limit - retained ||
                4 > local_limit - retained - live) {
              o.status = contour_generic::Status::capacity;
              o.error = "empty decoration admission";
            } else {
              o.rgba.assign(4, 0);
              o.width = o.height = 1;
              o.left = o.top = 0;
              o.status = contour_generic::Status::ok;
            }
          }
          retained += o.rgba.capacity();
          m[lane].known_peak_bytes =
              std::max(m[lane].known_peak_bytes,
                       retained + scratch(s) + o.metrics.known_capacity_peak_bytes);
          active.fetch_sub(1);
        }
      } catch (...) {
        lane_failed.store(true);
      }
      m[lane].cpu_sum_ns = now(CLOCK_THREAD_CPUTIME_ID) - began;
    };
    if (r.workers == 2) {
      std::thread second(worker, 1);
      worker(0);
      second.join();
    } else
      worker(0);
    if (lane_failed.load()) {
      out.error = "batch worker allocation or exception";
      return finish(contour_generic::Status::capacity);
    }
    out.metrics.active_peak = peak.load();
    out.metrics.source_rgba_bytes = r.length;
    out.metrics.known_peak_bytes = r.length;
    for (uint32_t i = 0; i < r.workers; i++) {
      out.metrics.cpu_sum_ns += m[i].cpu_sum_ns;
      out.metrics.trace_cpu_ns += m[i].trace_cpu_ns;
      out.metrics.backing_cpu_ns += m[i].backing_cpu_ns;
      out.metrics.composition_cpu_ns += m[i].composition_cpu_ns;
      out.metrics.known_peak_bytes += m[i].known_peak_bytes;
    }
    for (size_t j = 0; j < unique_count; j++) {
      const auto &t = tiles[unique[j]];
      if (t.status != contour_generic::Status::ok) {
        out.error = t.error;
        return finish(t.status);
      }
    }
    out.placements.resize(r.count);
    int x = r.gutter, y = r.gutter, row = 0, right = 0;
    uint64_t retained = 0;
    for (size_t i = 0; i < r.count; i++) {
      if (representative[i] != i) {
        out.placements[i] = out.placements[representative[i]];
        continue;
      }
      const auto &t = tiles[i];
      if (t.width + int(r.gutter) * 2 > int(r.atlas_width)) {
        out.error = "tile exceeds atlas width";
        return finish(contour_generic::Status::capacity);
      }
      if (x + t.width + int(r.gutter) > int(r.atlas_width)) {
        x = r.gutter;
        y += row + r.gutter;
        row = 0;
      }
      out.placements[i] = {x, y, t.width, t.height, t.left, t.top};
      x += t.width + r.gutter;
      right = std::max(right, x);
      row = std::max(row, t.height);
      retained += t.rgba.capacity();
    }
    out.width = unique_count < r.count ? uint32_t(right) : r.atlas_width;
    out.height = y + row + r.gutter;
    const uint64_t pixels = uint64_t(out.width) * out.height;
    if (pixels > r.atlas_pixel_limit || pixels * 4 > r.allocation_limit - r.length ||
        retained > r.allocation_limit - r.length - pixels * 4) {
      out.error = "output atlas admission";
      return finish(contour_generic::Status::capacity);
    }
    const auto pack = now(CLOCK_THREAD_CPUTIME_ID);
    out.rgba.assign(size_t(pixels) * 4, 0);
    for (size_t j = 0; j < unique_count; j++) {
      const size_t i = unique[j];
      const auto &t = tiles[i];
      const auto &p = out.placements[i];
      for (int row = 0; row < t.height; row++)
        std::memcpy(out.rgba.data() + (size_t(p.y + row) * out.width + p.x) * 4,
                    t.rgba.data() + size_t(row) * t.width * 4, size_t(t.width) * 4);
    }
    out.metrics.pack_cpu_ns = now(CLOCK_THREAD_CPUTIME_ID) - pack;
    out.metrics.cpu_sum_ns += out.metrics.pack_cpu_ns;
    out.metrics.output_rgba_bytes = out.rgba.size();
    out.metrics.known_peak_bytes =
        std::max(out.metrics.known_peak_bytes, r.length + retained + out.rgba.capacity());
    return finish(contour_generic::Status::ok);
  } catch (const std::bad_alloc &) {
    out.error = "batch allocation";
    return finish(contour_generic::Status::capacity);
  } catch (...) {
    out.error = "batch worker failure";
    return finish(contour_generic::Status::failed);
  }
}
}
