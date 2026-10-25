#include "contour_backing_raster.h"
#include "clipper2/clipper.h"
#include "scanline.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <memory>
#include <stdexcept>
#include <time.h>
#include <utility>
#include <vector>

namespace {
using namespace Clipper2Lib;
constexpr double kScale = 100000.0;
constexpr std::size_t kMaxCoordinates = 65536;
constexpr std::size_t kMaxLoops = 8192;
constexpr std::size_t kMaxVertices = 65536;
constexpr std::uint64_t kMaxGeometryWork = 100000000;
// Reserve headroom for Clipper's internal storage, which is not included in
// the explicitly tracked owned-buffer envelope.
constexpr std::uint64_t kClipperWorkingAllowance = 16ULL * 1024 * 1024;
constexpr std::uint64_t kSmallOwnedAllowance = 16 * 1024;
constexpr int kMaxDimension = 2048;
constexpr int kMaxPixels = 1024 * 1024;

struct Failure {
  contour_backing::Status type;
  std::string message;
};
[[noreturn]] void invalid(const char *message) {
  throw Failure{contour_backing::Status::invalid, message};
}
[[noreturn]] void capacity(const char *message) {
  throw Failure{contour_backing::Status::capacity, message};
}
[[noreturn]] void failed(const char *message) {
  throw Failure{contour_backing::Status::failed, message};
}
std::uint64_t add(std::uint64_t a, std::uint64_t b) {
  if (b > std::numeric_limits<std::uint64_t>::max() - a)
    capacity("Native byte-count overflow");
  return a + b;
}
std::uint64_t multiply(std::uint64_t a, std::uint64_t b) {
  if (a != 0 && b > std::numeric_limits<std::uint64_t>::max() / a)
    capacity("Native byte-count overflow");
  return a * b;
}
struct Work {
  contour_backing::CancelFn cancel;
  void *cancelUser;
  std::uint64_t allocationLimit;
  std::uint64_t ownedEnvelope = 0;
  std::uint64_t knownCapacityPeak = 0;
  std::uint64_t units = 0;
  void poll() const {
    if (cancel && cancel(cancelUser) != 0)
      throw Failure{contour_backing::Status::cancelled, "Native contour request cancelled"};
  }
  void tick() {
    if (++units > kMaxGeometryWork)
      capacity("Native geometry work budget exceeded");
    if ((units & 255) == 0)
      poll();
  }
  void admit(std::uint64_t bytes) {
    if (add(bytes, kClipperWorkingAllowance) > allocationLimit)
      capacity("Native owned-buffer envelope and Clipper working allowance exceed allocationLimit");
    ownedEnvelope = std::max(ownedEnvelope, bytes);
  }
  void observe(std::uint64_t bytes) {
    if (bytes > ownedEnvelope)
      capacity("Native known buffer capacities exceed the admitted envelope");
    knownCapacityPeak = std::max(knownCapacityPeak, bytes);
  }
};
int64_t clockNs(clockid_t clock) {
  timespec value{};
  if (clock_gettime(clock, &value) != 0)
    failed("Clock unavailable");
  return static_cast<int64_t>(value.tv_sec) * 1000000000 + value.tv_nsec;
}
struct Stamp {
  int64_t wall = clockNs(CLOCK_MONOTONIC);
  int64_t cpu = clockNs(CLOCK_THREAD_CPUTIME_ID);
};
struct CurvePoint {
  double x, y;
};
struct Statistics {
  std::size_t vertices = 0;
  int depth = 0;
};
struct Crop {
  double left, top;
  int width, height;
};
struct Geometry {
  Paths64 paths;
  Crop crop{};
  Statistics statistics;
  std::size_t sourceVertices = 0;
  std::size_t rawSourceVertices = 0;
  bool reversed = false;
  Stamp flattened;
  Stamp normalized;
  Stamp generated;
};
std::uint64_t pathBytes(const Paths64 &paths) {
  std::uint64_t result = sizeof(paths) + multiply(paths.capacity(), sizeof(Path64));
  for (const auto &path : paths)
    result = add(result, multiply(path.capacity(), sizeof(Point64)));
  return result;
}
std::size_t vertices(const Paths64 &paths) {
  std::size_t result = 0;
  for (const auto &path : paths) {
    if (path.size() > kMaxVertices - result)
      capacity("Native source or offset vertex cap exceeded");
    result += path.size();
  }
  return result;
}
CurvePoint midpoint(CurvePoint a, CurvePoint b) {
  return {(a.x + b.x) * .5, (a.y + b.y) * .5};
}
double distance(CurvePoint p, CurvePoint a, CurvePoint b) {
  double dx = b.x - a.x, dy = b.y - a.y, length2 = dx * dx + dy * dy;
  double t = length2 > 0 ? ((p.x - a.x) * dx + (p.y - a.y) * dy) / length2 : 0;
  t = std::clamp(t, 0.0, 1.0);
  return std::hypot(p.x - a.x - t * dx, p.y - a.y - t * dy);
}
void append(Path64 &path, CurvePoint p, Statistics &statistics, Work &work) {
  work.tick();
  if (!std::isfinite(p.x) || !std::isfinite(p.y) || std::abs(p.x) > 1e7 || std::abs(p.y) > 1e7)
    invalid("Invalid physical coordinate");
  Point64 value{std::llround(p.x * kScale), std::llround(p.y * kScale)};
  if (!path.empty() && path.back() == value)
    return;
  if (++statistics.vertices > kMaxVertices)
    capacity("Flattened source vertex cap exceeded");
  path.push_back(value);
}
void flatten(CurvePoint a, CurvePoint b, CurvePoint c, CurvePoint d, double epsilon, Path64 &output,
             Statistics &statistics, Work &work, int depth = 0) {
  work.tick();
  if (std::max(distance(b, a, d), distance(c, a, d)) <= epsilon) {
    append(output, d, statistics, work);
    return;
  }
  if (depth >= 32)
    capacity("Cubic subdivision depth exceeded");
  statistics.depth = std::max(statistics.depth, depth + 1);
  CurvePoint ab = midpoint(a, b), bc = midpoint(b, c), cd = midpoint(c, d);
  CurvePoint abc = midpoint(ab, bc), bcd = midpoint(bc, cd), middle = midpoint(abc, bcd);
  flatten(a, ab, abc, middle, epsilon, output, statistics, work, depth + 1);
  flatten(middle, bcd, cd, d, epsilon, output, statistics, work, depth + 1);
}
double segmentDistanceSquared(const Point64 &p, const Point64 &a, const Point64 &b) {
  double dx = static_cast<double>(b.x) - a.x, dy = static_cast<double>(b.y) - a.y;
  double px = static_cast<double>(p.x) - a.x, py = static_cast<double>(p.y) - a.y;
  double size = dx * dx + dy * dy;
  double t = size > 0 ? (px * dx + py * dy) / size : 0;
  t = std::clamp(t, 0.0, 1.0);
  double rx = px - t * dx, ry = py - t * dy;
  return rx * rx + ry * ry;
}
Path64 simplifyClosed(const Path64 &path, double epsilon, Work &work, std::uint64_t retainedBytes) {
  if (path.size() < 8)
    return path;
  std::size_t n = path.size();
  std::vector<uint8_t> kept(n + 1, 0);
  std::vector<std::pair<std::size_t, std::size_t>> stack;
  stack.reserve(n);
  for (std::size_t quarter = 0; quarter < 4; quarter++) {
    std::size_t first = n * quarter / 4, last = n * (quarter + 1) / 4;
    kept[first] = kept[last] = 1;
    stack.emplace_back(first, last);
  }
  double limit = epsilon * kScale;
  limit *= limit;
  while (!stack.empty()) {
    work.tick();
    auto range = stack.back();
    stack.pop_back();
    std::size_t split = range.first;
    double farthest = limit;
    const Point64 &a = path[range.first];
    const Point64 &b = path[range.second % n];
    for (std::size_t i = range.first + 1; i < range.second; i++) {
      work.tick();
      double d = segmentDistanceSquared(path[i], a, b);
      if (d > farthest) {
        farthest = d;
        split = i;
      }
    }
    if (split == range.first)
      continue;
    kept[split] = 1;
    if (split > range.first + 1)
      stack.emplace_back(range.first, split);
    if (split + 1 < range.second)
      stack.emplace_back(split, range.second);
  }
  Path64 result;
  result.reserve(n);
  work.observe(add(retainedBytes,
                   add(multiply(path.capacity(), sizeof(Point64)),
                       add(kept.capacity(), add(multiply(stack.capacity(), sizeof(stack[0])),
                                                multiply(result.capacity(), sizeof(Point64)))))));
  for (std::size_t i = 0; i < n; i++) {
    work.tick();
    if (kept[i])
      result.push_back(path[i]);
  }
  if (result.size() < 3)
    return path;
  return result;
}
void checkCoordinates(const double *values, std::size_t length, Work &work) {
  for (std::size_t i = 0; i < length; i++) {
    work.tick();
    if (!std::isfinite(values[i]) || std::abs(values[i]) > 1e7)
      invalid("All source coordinates must be finite and within 10000000 physical pixels");
  }
}
Geometry prepare(const contour_backing::Curves &input, double amount, int pixelLimit, int padLeft,
                 int padTop, int padRight, int padBottom, Work &work) {
  work.poll();
  if (!std::isfinite(amount) || amount < .5 || amount > 1024 || pixelLimit < 1 ||
      pixelLimit > kMaxPixels || padLeft < 0 || padTop < 0 || padRight < 0 || padBottom < 0)
    invalid("Invalid native contour contract");
  const std::size_t loops = input.size();
  if (loops < 1 || loops > kMaxLoops)
    invalid("Source contour count exceeds its bound");
  std::size_t coordinates = 0, maxCurve = 0;
  for (const auto &curve : input) {
    work.poll();
    const std::size_t length = curve.size();
    if (length < 8 || (length - 2) % 6 != 0 || length > kMaxCoordinates - coordinates)
      invalid("Source requires at most 65536 coordinates and complete cubics");
    coordinates += length;
    maxCurve = std::max(maxCurve, length);
    checkCoordinates(curve.data(), length, work);
  }
  // Qualified accounting envelope, not a proof of allocator or Clipper RSS.
  work.admit(add(add(multiply(128, kMaxVertices), multiply(80, static_cast<std::size_t>(loops))),
                 add(multiply(8, maxCurve), kSmallOwnedAllowance)));
  Geometry geometry;
  Paths64 rawSource;
  rawSource.reserve(loops);
  for (std::size_t ci = 0; ci < loops; ci++) {
    work.poll();
    const auto &c = input[ci];
    const std::size_t length = c.size();
    checkCoordinates(c.data(), c.size(), work);
    Path64 path;
    CurvePoint current{c[0], c[1]};
    append(path, current, geometry.statistics, work);
    for (std::size_t i = 2; i < length; i += 6) {
      CurvePoint end{c[i + 4], c[i + 5]};
      flatten(current, {c[i], c[i + 1]}, {c[i + 2], c[i + 3]}, end, .01, path, geometry.statistics,
              work);
      current = end;
    }
    if (path.size() > 1 && path.front() == path.back())
      path.pop_back();
    const auto retained = add(pathBytes(rawSource), multiply(c.size(), sizeof(double)));
    work.observe(add(retained, multiply(path.capacity(), sizeof(Point64))));
    if (path.size() >= 3)
      rawSource.push_back(simplifyClosed(path, .04, work, retained));
    work.observe(pathBytes(rawSource));
  }
  geometry.rawSourceVertices = vertices(rawSource);
  geometry.flattened = Stamp{};
  Paths64 source;
  {
    work.poll();
    Clipper64 normalizer;
    normalizer.AddSubject(rawSource);
    work.poll();
    const bool succeeded = normalizer.Execute(ClipType::Union, FillRule::EvenOdd, source);
    work.poll();
    if (!succeeded || normalizer.ErrorCode() != 0 || source.empty())
      failed("Source normalization failed or empty");
    geometry.sourceVertices = vertices(source);
    work.observe(add(pathBytes(rawSource), pathBytes(source)));
  }
  Paths64().swap(rawSource);
  geometry.normalized = Stamp{};
  double minX = INFINITY, minY = INFINITY, maxX = -INFINITY, maxY = -INFINITY;
  for (const auto &path : source)
    for (const auto &point : path) {
      work.tick();
      minX = std::min(minX, point.x / kScale);
      minY = std::min(minY, point.y / kScale);
      maxX = std::max(maxX, point.x / kScale);
      maxY = std::max(maxY, point.y / kScale);
    }
  const double left = std::floor(minX - amount - 1) - padLeft;
  const double top = std::floor(minY - amount - 1) - padTop;
  const double right = std::ceil(maxX + amount + 1) + padRight;
  const double bottom = std::ceil(maxY + amount + 1) + padBottom;
  const double width = right - left, height = bottom - top;
  if (!std::isfinite(left) || !std::isfinite(top) || !std::isfinite(width) ||
      !std::isfinite(height) || width < 1 || height < 1 || width > kMaxDimension ||
      height > kMaxDimension || width * height > pixelLimit)
    invalid("Native crop exceeds the output pixel or dimension limit");
  geometry.crop = {left, top, static_cast<int>(width), static_cast<int>(height)};
  const double steps =
      std::ceil(3.141592653589793 / std::acos(std::clamp(1 - .05 / amount, -1., 1.))) + 1;
  if (!std::isfinite(steps) || geometry.sourceVertices * steps > kMaxVertices)
    capacity("Offset generation preflight exceeds its conservative vertex bound");
  work.poll();
  {
    ClipperOffset generator(2, .05 * kScale);
    generator.AddPaths(source, JoinType::Round, EndType::Polygon);
    work.poll();
    generator.ExecuteRaw(amount * kScale, geometry.paths, geometry.reversed);
    work.poll();
    if (generator.ErrorCode() != 0 || geometry.paths.empty())
      failed("Offset contour generation failed or empty");
    vertices(geometry.paths);
    work.observe(add(pathBytes(source), pathBytes(geometry.paths)));
  }
  geometry.generated = Stamp{};
  return geometry;
}
void writeMeasures(contour_backing::Output &output, const Stamp &begin, const Geometry &geometry,
                   const Stamp &created, const Stamp &allocated, const Stamp &rendered,
                   const Stamp &destroyed, const Stamp &copied, const sc_stats &raster, int rule,
                   const Work &work) {
  const auto &f = geometry.flattened;
  const auto &n = geometry.normalized;
  const auto &g = geometry.generated;
  output.metrics = {f.wall - begin.wall,
                    f.cpu - begin.cpu,
                    n.wall - f.wall,
                    n.cpu - f.cpu,
                    g.wall - n.wall,
                    g.cpu - n.cpu,
                    created.wall - g.wall,
                    created.cpu - g.cpu,
                    allocated.wall - created.wall,
                    allocated.cpu - created.cpu,
                    rendered.wall - allocated.wall,
                    rendered.cpu - allocated.cpu,
                    copied.wall - destroyed.wall,
                    copied.cpu - destroyed.cpu,
                    destroyed.wall - rendered.wall,
                    destroyed.cpu - rendered.cpu,
                    geometry.crop.width,
                    geometry.crop.height,
                    static_cast<std::int64_t>(geometry.statistics.vertices),
                    static_cast<std::int64_t>(geometry.sourceVertices),
                    static_cast<std::int64_t>(vertices(geometry.paths)),
                    static_cast<std::int64_t>(geometry.paths.size()),
                    0,
                    copied.wall - begin.wall,
                    static_cast<std::int64_t>(raster.segment_visits),
                    static_cast<std::int64_t>(raster.sort_comparisons),
                    static_cast<std::int64_t>(raster.max_active),
                    static_cast<std::int64_t>(raster.intervals),
                    rule,
                    static_cast<std::int64_t>(geometry.rawSourceVertices),
                    copied.cpu - begin.cpu,
                    static_cast<std::int64_t>(raster.pixel_writes),
                    static_cast<std::int64_t>(work.ownedEnvelope),
                    static_cast<std::int64_t>(kClipperWorkingAllowance),
                    static_cast<std::int64_t>(work.units),
                    static_cast<std::int64_t>(work.knownCapacityPeak)};
  output.left = geometry.crop.left;
  output.top = geometry.crop.top;
  output.width = geometry.crop.width;
  output.height = geometry.crop.height;
}
} // namespace

namespace contour_backing {
Status render(const Curves &input, double amount, Output &output, const Limits &limits,
              CancelFn cancel, void *cancel_user) {
  output.error.clear();
  output.metrics.fill(0);
  output.status = Status::failed;
  if (std::isfinite(amount) && amount >= 0 && amount < .5) {
    output.alpha.clear();
    output.width = 0;
    output.height = 0;
    output.left = 0;
    output.top = 0;
    output.status = Status::unsupported;
    output.error = "Amounts below .5 physical pixels require the qualified fill path";
    return output.status;
  }
  try {
    const Stamp begin;
    Work work{cancel, cancel_user, limits.allocation_limit};
    auto geometry = prepare(input, amount, limits.output_pixel_limit, limits.pad_left,
                            limits.pad_top, limits.pad_right, limits.pad_bottom, work);
    const auto count = vertices(geometry.paths);
    const auto pixels = multiply(geometry.crop.width, geometry.crop.height);
    const auto rasterEnvelope = add(add(multiply(120, count), multiply(16, geometry.crop.width)),
                                    add(8 + 2 * pixels, kSmallOwnedAllowance));
    work.admit(add(pathBytes(geometry.paths), rasterEnvelope));
    std::vector<double> segments;
    segments.reserve(count * 4);
    for (const auto &path : geometry.paths)
      if (path.size() >= 3)
        for (std::size_t i = 0; i < path.size(); i++) {
          work.tick();
          const auto &a = path[i];
          const auto &b = path[(i + 1) % path.size()];
          segments.insert(segments.end(),
                          {a.x / kScale - geometry.crop.left, a.y / kScale - geometry.crop.top,
                           b.x / kScale - geometry.crop.left, b.y / kScale - geometry.crop.top});
        }
    work.observe(add(pathBytes(geometry.paths), multiply(segments.capacity(), sizeof(double))));
    work.poll();
    int32_t status = 0;
    void *pointer = sc_create(segments.data(), static_cast<int32_t>(segments.size() / 4),
                              geometry.reversed ? 3 : 2, &status);
    if (!pointer || status != 0) {
      if (status == 2 || status == 3)
        capacity("Scanline context allocation or segment budget failed");
      failed("Scanline context failed");
    }
    std::unique_ptr<void, decltype(&sc_destroy)> context(pointer, sc_destroy);
    work.poll();
    const Stamp created;
    // Reuse equal-size caller storage while retaining the accepted allocation envelope.
    if (output.alpha.capacity() != pixels)
      std::vector<std::uint8_t>(static_cast<std::size_t>(pixels)).swap(output.alpha);
    else
      output.alpha.assign(static_cast<std::size_t>(pixels), 0);
    const auto retainedKnown =
        add(pathBytes(geometry.paths),
            add(multiply(segments.capacity(), sizeof(double)),
                add(sc_owned_context_bytes(context.get()), output.alpha.capacity())));
    work.observe(retainedKnown);
    const Stamp allocated;
    sc_stats raster{};
    status = sc_render(context.get(), geometry.crop.width, geometry.crop.height, 0, 8,
                       output.alpha.data(), work.cancel, work.cancelUser, &raster);
    work.observe(add(retainedKnown, raster.scratch_bytes));
    if (status == 4)
      work.poll();
    if (status == 2 || status == 3)
      capacity("Scanline allocation or work budget exceeded");
    if (status != 0)
      failed("Positive scanline render failed");
    work.poll();
    const Stamp rendered;
    context.reset();
    const Stamp destroyed;
    work.poll();
    const Stamp copied;
    writeMeasures(output, begin, geometry, created, allocated, rendered, destroyed, copied, raster,
                  geometry.reversed ? 3 : 2, work);
    output.status = Status::ok;
    return output.status;
  } catch (const Failure &error) {
    output.status = error.type;
    output.error = error.message;
  } catch (const std::bad_alloc &) {
    output.status = Status::capacity;
    output.error = "Native contour allocation failed";
  } catch (const std::exception &error) {
    output.status = Status::failed;
    output.error = error.what();
  } catch (...) {
    output.status = Status::failed;
    output.error = "Native contour operation failed";
  }
  output.alpha.clear();
  output.width = 0;
  output.height = 0;
  output.left = 0;
  output.top = 0;
  return output.status;
}
} // namespace contour_backing
