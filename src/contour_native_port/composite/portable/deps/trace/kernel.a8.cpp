#include <algorithm>
#include <atomic>
#include <cstddef>
#include <new>
#include <type_traits>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <vector>

namespace {
struct Budget {
  uint64_t limit = 0;
  std::atomic<uint64_t> live{0}, peak{0};
  std::atomic<bool> denied{false};
};
std::atomic<uint64_t> liveBytes{0}, peakBytes{0}, liveJobs{0}, calls{0}, rejectedDestroys{0};
thread_local Budget *currentBudget = nullptr;
void updatePeak(std::atomic<uint64_t> &peak, uint64_t value) {
  auto old = peak.load();
  while (old < value && !peak.compare_exchange_weak(old, value)) {
  }
}
void charge(Budget *budget, uint64_t bytes) {
  if (budget) {
    auto current = budget->live.load();
    do {
      if (bytes > budget->limit - current) {
        budget->denied = true;
        throw std::bad_alloc();
      }
    } while (!budget->live.compare_exchange_weak(current, current + bytes));
    updatePeak(budget->peak, current + bytes);
  }
  updatePeak(peakBytes, liveBytes.fetch_add(bytes) + bytes);
}
void uncharge(Budget *budget, uint64_t bytes) {
  if (budget)
    budget->live.fetch_sub(bytes);
  liveBytes.fetch_sub(bytes);
}
struct alignas(std::max_align_t) AllocationHeader {
  uint64_t bytes;
  Budget *budget;
};
void *trackedAllocate(size_t bytes) {
  if (bytes > std::numeric_limits<size_t>::max() - sizeof(AllocationHeader))
    throw std::bad_alloc();
  const size_t total = bytes + sizeof(AllocationHeader);
  Budget *budget = currentBudget;
  charge(budget, total);
  auto *header = static_cast<AllocationHeader *>(std::malloc(total));
  if (!header) {
    uncharge(budget, total);
    throw std::bad_alloc();
  }
  header->bytes = total;
  header->budget = budget;
  return header + 1;
}
void trackedFree(void *pointer) {
  if (!pointer)
    return;
  auto *header = static_cast<AllocationHeader *>(pointer) - 1;
  uncharge(header->budget, header->bytes);
  std::free(header);
}
class BudgetScope {
public:
  explicit BudgetScope(Budget *budget) : previous(currentBudget) {
    currentBudget = budget;
  }
  ~BudgetScope() {
    currentBudget = previous;
  }

private:
  Budget *previous;
};
template <class T> class TrackedAllocator {
public:
  using value_type = T;
  using propagate_on_container_move_assignment = std::true_type;
  Budget *owner = currentBudget;
  TrackedAllocator() noexcept = default;
  template <class U>
  TrackedAllocator(const TrackedAllocator<U> &other) noexcept : owner(other.owner) {}
  T *allocate(size_t count) {
    if (count > std::numeric_limits<size_t>::max() / sizeof(T))
      throw std::bad_alloc();
    BudgetScope scope(owner);
    return static_cast<T *>(trackedAllocate(count * sizeof(T)));
  }
  void deallocate(T *pointer, size_t) noexcept {
    trackedFree(pointer);
  }
  template <class U> bool operator==(const TrackedAllocator<U> &other) const noexcept {
    return owner == other.owner;
  }
  template <class U> bool operator!=(const TrackedAllocator<U> &other) const noexcept {
    return !(*this == other);
  }
};
template <class T> using Vector = std::vector<T, TrackedAllocator<T>>;

struct Point {
  double x, y;
};
using Curve = Vector<double>;
constexpr size_t kGeometryBytes = 4 * 1024 * 1024;
constexpr size_t kMetadataBytes = 64;
constexpr size_t kMaximumPoints = 32768;

class Simplifier {
public:
  static Curve simplify(Curve &&curve, double ratio) {
    if (curve.size() < 98)
      return std::move(curve);
    return Simplifier(curve, .05 * ratio).run();
  }

private:
  const Curve &curve;
  double tolerance;
  Curve output;
  double candidate[8]{};
  Simplifier(const Curve &c, double t) : curve(c), tolerance(t) {
    output.reserve(c.size());
  }
  Curve run() {
    output.push_back(curve[0]);
    output.push_back(curve[1]);
    const size_t count = (curve.size() - 2) / 6;
    for (size_t q = 0; q < 4; q++)
      range(count * q / 4, count * (q + 1) / 4);
    return std::move(output);
  }
  void range(size_t first, size_t end) {
    if (end - first == 1) {
      output.insert(output.end(), curve.begin() + first * 6 + 2, curve.begin() + first * 6 + 8);
      return;
    }
    if (fit(first, end)) {
      output.insert(output.end(), candidate + 2, candidate + 8);
      return;
    }
    const size_t middle = (first + end) / 2;
    range(first, middle);
    range(middle, end);
  }
  static bool close(double ax, double ay, double bx, double by, double ts) {
    const double dx = ax - bx, dy = ay - by;
    return dx * dx + dy * dy <= ts;
  }
  static double evaluate(double a, double b, double c, double d, double t) {
    const double u = 1 - t;
    return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
  }
  static double derivativeThird(double a, double b, double c, double d, double t) {
    const double u = 1 - t;
    return u * u * (b - a) + 2 * u * t * (c - b) + t * t * (d - c);
  }
  bool fit(size_t first, size_t end) {
    const size_t count = end - first, base = first * 6, last = end * 6;
    const double x0 = curve[base], y0 = curve[base + 1], x3 = curve[last], y3 = curve[last + 1];
    double tx0 = curve[base + 2] - x0, ty0 = curve[base + 3] - y0, tx1 = curve[last - 2] - x3,
           ty1 = curve[last - 1] - y3;
    const double length0 = std::sqrt(tx0 * tx0 + ty0 * ty0),
                 length1 = std::sqrt(tx1 * tx1 + ty1 * ty1);
    if (length0 == 0 || length1 == 0)
      return false;
    tx0 /= length0;
    ty0 /= length0;
    tx1 /= length1;
    ty1 /= length1;
    const double dot = tx0 * tx1 + ty0 * ty1;
    double c00 = 0, c01 = 0, c11 = 0, rhs0 = 0, rhs1 = 0;
    for (size_t i = 1; i < count * 2; i++) {
      const size_t point = (first + i / 2) * 6;
      const bool midpoint = i % 2;
      const double px =
          midpoint
              ? (curve[point] + 3 * curve[point + 2] + 3 * curve[point + 4] + curve[point + 6]) / 8
              : curve[point];
      const double py = midpoint ? (curve[point + 1] + 3 * curve[point + 3] + 3 * curve[point + 5] +
                                    curve[point + 7]) /
                                       8
                                 : curve[point + 1];
      const double t = double(i) / (count * 2), u = 1 - t, a = 3 * u * u * t, b = 3 * u * t * t;
      const double rx = px - u * u * (1 + 2 * t) * x0 - t * t * (3 - 2 * t) * x3,
                   ry = py - u * u * (1 + 2 * t) * y0 - t * t * (3 - 2 * t) * y3;
      c00 += a * a;
      c01 += a * b * dot;
      c11 += b * b;
      rhs0 += a * (tx0 * rx + ty0 * ry);
      rhs1 += b * (tx1 * rx + ty1 * ry);
    }
    const double determinant = c00 * c11 - c01 * c01;
    if (determinant <= 1e-12)
      return false;
    const double handle0 = (rhs0 * c11 - rhs1 * c01) / determinant,
                 handle1 = (c00 * rhs1 - c01 * rhs0) / determinant;
    if (handle0 <= 0 || handle1 <= 0)
      return false;
    const double x1 = x0 + handle0 * tx0, y1 = y0 + handle0 * ty0, x2 = x3 + handle1 * tx1,
                 y2 = y3 + handle1 * ty1;
    const double ts = tolerance * tolerance;
    for (size_t i = 0; i < count; i++) {
      const double a = double(i) / count, b = double(i + 1) / count;
      const double ax = evaluate(x0, x1, x2, x3, a), ay = evaluate(y0, y1, y2, y3, a),
                   bx = evaluate(x0, x1, x2, x3, b), by = evaluate(y0, y1, y2, y3, b);
      const double aa = derivativeThird(x0, x1, x2, x3, a) / count,
                   ab = derivativeThird(y0, y1, y2, y3, a) / count,
                   ba = derivativeThird(x0, x1, x2, x3, b) / count,
                   bb = derivativeThird(y0, y1, y2, y3, b) / count;
      const size_t o = (first + i) * 6;
      if (!close(ax, ay, curve[o], curve[o + 1], ts) ||
          !close(ax + aa, ay + ab, curve[o + 2], curve[o + 3], ts) ||
          !close(bx - ba, by - bb, curve[o + 4], curve[o + 5], ts) ||
          !close(bx, by, curve[o + 6], curve[o + 7], ts))
        return false;
    }
    candidate[0] = x0;
    candidate[1] = y0;
    candidate[2] = x1;
    candidate[3] = y1;
    candidate[4] = x2;
    candidate[5] = y2;
    candidate[6] = x3;
    candidate[7] = y3;
    return true;
  }
};

Vector<uint8_t> coverage(const uint8_t *rgba, size_t width, size_t height, double ratio,
                         size_t pixelStride = 4, size_t alphaOffset = 3) {
  const size_t stride = width + 2, rows = height + 2;
  Vector<uint8_t> mask(stride * rows);
  size_t nonzero = 0;
  for (size_t y = 0; y < height; y++)
    for (size_t x = 0; x < width; x++) {
      const uint8_t alpha = rgba[(y * width + x) * pixelStride + alphaOffset];
      mask[(y + 1) * stride + x + 1] = alpha;
      if (alpha != 0)
        nonzero++;
    }
  if (nonzero == 0)
    return mask;
  Vector<uint8_t> out(mask.size()), visited(mask.size());
  Vector<uint32_t> component(nonzero);
  const int opacityFloor = std::max(1, int(std::ceil(.03 * 255)));
  const double minimumAlphaArea = .25 * 255 * ratio * ratio;
  for (size_t y = 1; y <= height; y++)
    for (size_t x = 1; x <= width; x++) {
      const size_t start = y * stride + x;
      if (mask[start] == 0 || visited[start] != 0)
        continue;
      size_t count = 1;
      int peak = 0;
      uint64_t alphaArea = 0;
      component[0] = uint32_t(start);
      visited[start] = 1;
      for (size_t head = 0; head < count; head++) {
        const size_t index = component[head];
        peak = std::max(peak, int(mask[index]));
        alphaArea += mask[index];
        const size_t nexts[8] = {index - stride - 1, index - stride,    index - stride + 1,
                                 index - 1,          index + 1,         index + stride - 1,
                                 index + stride,     index + stride + 1};
        for (const size_t next : nexts)
          if (mask[next] != 0 && visited[next] == 0) {
            visited[next] = 1;
            component[count++] = uint32_t(next);
          }
      }
      if (peak < opacityFloor || (peak < 128 && alphaArea < minimumAlphaArea))
        continue;
      for (size_t pixel = 0; pixel < count; pixel++) {
        const size_t i = component[pixel];
        if (mask[i] == peak) {
          out[i] = 255;
          continue;
        }
        const bool boundary = mask[i] < opacityFloor || mask[i - stride - 1] < opacityFloor ||
                              mask[i - stride] < opacityFloor ||
                              mask[i - stride + 1] < opacityFloor || mask[i - 1] < opacityFloor ||
                              mask[i + 1] < opacityFloor || mask[i + stride - 1] < opacityFloor ||
                              mask[i + stride] < opacityFloor ||
                              mask[i + stride + 1] < opacityFloor;
        out[i] = boundary ? uint8_t(std::floor(double(mask[i]) * 255 / peak + .5)) : 255;
      }
    }
  return out;
}
int bits(const Vector<uint8_t> &c, size_t i, size_t stride) {
  return (c[i] >= 128 ? 1 : 0) | (c[i + 1] >= 128 ? 2 : 0) | (c[i + stride + 1] >= 128 ? 4 : 0) |
         (c[i + stride] >= 128 ? 8 : 0);
}
Point position(size_t x, size_t y, bool horizontal, const Vector<uint8_t> &c, size_t stride) {
  const int first = c[y * stride + x], second = c[y * stride + x + (horizontal ? 1 : stride)];
  const double fraction = (127.5 - first) / (second - first);
  return {double(x) - .5 + (horizontal ? fraction : 0),
          double(y) - .5 + (horizontal ? 0 : fraction)};
}
bool curve(const Vector<Point> &points, size_t maximumBytes, Curve &result) {
  Vector<double> lengths(points.size());
  double perimeter = 0;
  for (size_t i = 0; i < points.size(); i++) {
    const auto &start = points[i];
    const auto &end = points[(i + 1) % points.size()];
    const double dx = end.x - start.x, dy = end.y - start.y, length = std::sqrt(dx * dx + dy * dy);
    lengths[i] = length;
    perimeter += length;
  }
  const size_t count = std::max(size_t(4), size_t(std::ceil(perimeter / 2)));
  if ((2 + count * 6) * sizeof(double) > maximumBytes)
    return false;
  Curve samples(count * 2);
  size_t edge = 0;
  double traversed = 0;
  for (size_t i = 0; i < count; i++) {
    const double distance = perimeter * i / count;
    while (edge < lengths.size() - 1 && traversed + lengths[edge] < distance)
      traversed += lengths[edge++];
    const double fraction = lengths[edge] == 0 ? 0 : (distance - traversed) / lengths[edge];
    const auto &start = points[edge];
    const auto &end = points[(edge + 1) % points.size()];
    samples[i * 2] = start.x * (1 - fraction) + end.x * fraction;
    samples[i * 2 + 1] = start.y * (1 - fraction) + end.y * fraction;
  }
  Curve knots = count < 8 ? std::move(samples) : Curve(count * 2);
  if (count >= 8)
    for (size_t i = 0; i < count; i++) {
      double x = samples[i * 2], y = samples[i * 2 + 1], weight = 1;
      const double weights[3] = {.4111122905, .0285655008, .0003354626};
      for (size_t offset = 1; offset <= 3; offset++) {
        const double contribution = weights[offset - 1];
        const size_t previous = ((i + count - offset) % count) * 2,
                     next = ((i + offset) % count) * 2;
        x += (samples[previous] + samples[next]) * contribution;
        y += (samples[previous + 1] + samples[next + 1]) * contribution;
        weight += contribution * 2;
      }
      knots[i * 2] = x / weight;
      knots[i * 2 + 1] = y / weight;
    }
  result.resize(2 + count * 6);
  result[0] = knots[0];
  result[1] = knots[1];
  for (size_t i = 0; i < count; i++) {
    const size_t previous = ((i + count - 1) % count) * 2, start = i * 2,
                 end = ((i + 1) % count) * 2, next = ((i + 2) % count) * 2, base = 2 + i * 6;
    result[base] = knots[start] + (knots[end] - knots[previous]) / 6;
    result[base + 1] = knots[start + 1] + (knots[end + 1] - knots[previous + 1]) / 6;
    result[base + 2] = knots[end] - (knots[next] - knots[start]) / 6;
    result[base + 3] = knots[end + 1] - (knots[next + 1] - knots[start + 1]) / 6;
    result[base + 4] = knots[end];
    result[base + 5] = knots[end + 1];
  }
  return true;
}
bool trace(const uint8_t *rgba, size_t width, size_t height, double ratio, Vector<Curve> &contours,
           size_t pixelStride = 4, size_t alphaOffset = 3) {
  const size_t stride = width + 2, rows = height + 2, columns = stride - 1;
  const auto c = coverage(rgba, width, height, ratio, pixelStride, alphaOffset);
  Vector<uint8_t> visited(columns * (rows - 1));
  size_t geometryBytes = 0;
  const int firstSides[16] = {0, 1, 2, 2, 4, 1, 4, 4, 4, 4, 8, 4, 2, 2, 1, 0};
  const int exits[16] = {0x0,    0x1008, 0x12,   0x2080, 0x240,  0x4812, 0x104,  0x4800,
                         0x4800, 0x104,  0x1248, 0x240,  0x2080, 0x12,   0x1008, 0x0};
  for (size_t y = 0; y + 1 < rows; y++)
    for (size_t x = 0; x + 1 < stride; x++) {
      // Eight cells share nine pixels from each row. Skip only cells whose
      // threshold bits are all zero or all one; neither can start a contour.
      // memcpy keeps unaligned loads defined, and byte-high masks are endian-neutral.
      if ((x & 7) == 0 && x + 8 < stride) {
        uint64_t top, bottom;
        std::memcpy(&top, c.data() + y * stride + x, sizeof(top));
        std::memcpy(&bottom, c.data() + (y + 1) * stride + x, sizeof(bottom));
        constexpr uint64_t highBits = 0x8080808080808080ULL;
        const int edgeTop = c[y * stride + x + 8], edgeBottom = c[(y + 1) * stride + x + 8];
        if ((((top | bottom) & highBits) == 0 && (edgeTop | edgeBottom) < 128) ||
            (((top & bottom) & highBits) == highBits && (edgeTop & edgeBottom) >= 128)) {
          x += 7;
          continue;
        }
      }
      const int initialBits = bits(c, y * stride + x, stride);
      if (initialBits == 0 || initialBits == 15)
        continue;
      int side = firstSides[initialBits];
      const size_t cell = y * columns + x;
      if ((visited[cell] & side) != 0) {
        if (initialBits == 5)
          side = 4;
        else if (initialBits == 10)
          side = 2;
        else
          continue;
        if ((visited[cell] & side) != 0)
          continue;
      }
      const size_t startX = x, startY = y;
      const int startSide = side;
      size_t cx = x, cy = y;
      int currentBits = initialBits;
      Vector<Point> points;
      do {
        if (points.size() >= kMaximumPoints)
          return false;
        points.push_back(position(side == 2 ? cx + 1 : cx, side == 4 ? cy + 1 : cy,
                                  side == 1 || side == 4, c, stride));
        const int shift = side == 1 ? 0 : side == 2 ? 4 : side == 4 ? 8 : 12;
        const int exit = (exits[currentBits] >> shift) & 15;
        if (exit == 0)
          throw std::runtime_error("no exit");
        visited[cy * columns + cx] |= uint8_t(side | exit);
        switch (exit) {
        case 1:
          cy--;
          side = 4;
          break;
        case 2:
          cx++;
          side = 8;
          break;
        case 4:
          cy++;
          side = 1;
          break;
        case 8:
          cx--;
          side = 2;
          break;
        }
        currentBits = bits(c, cy * stride + cx, stride);
      } while (cx != startX || cy != startY || side != startSide);
      if (points.size() >= 3) {
        if (geometryBytes + kMetadataBytes > kGeometryBytes)
          return false;
        Curve raw;
        if (!curve(points, kGeometryBytes - geometryBytes - kMetadataBytes, raw))
          return false;
        auto simplified = Simplifier::simplify(std::move(raw), ratio);
        geometryBytes += simplified.size() * sizeof(double) + kMetadataBytes;
        contours.push_back(std::move(simplified));
      }
    }
  return true;
}
}
extern "C" {
struct CtOutput {
  int32_t status;
  uint32_t count;
  uint64_t value_count;
  uint32_t *lengths;
  double *values;
};
void ct_free(CtOutput *output) {
  if (!output)
    return;
  trackedFree(output->lengths);
  trackedFree(output->values);
  *output = {};
}
int32_t ct_trace_a8(const uint8_t *rgba, uint64_t length, uint32_t width, uint32_t height,
                    double ratio, CtOutput *output) {
  calls.fetch_add(1);
  if (!output)
    return 2;
  *output = {};
  const uint64_t pixels = uint64_t(width) * height,
                 padded = (uint64_t(width) + 2) * (uint64_t(height) + 2);
  if (!rgba || pixels > length || padded > std::numeric_limits<uint32_t>::max() ||
      !std::isfinite(ratio) || ratio <= 0)
    return output->status = 2;
  try {
    Vector<Curve> contours;
    if (!trace(rgba, width, height, ratio, contours, 1, 0))
      return output->status = 1;
    uint64_t values = 0;
    for (const auto &c : contours)
      values += c.size();
    if (!contours.empty()) {
      output->lengths =
          static_cast<uint32_t *>(trackedAllocate(contours.size() * sizeof(uint32_t)));
      output->values = static_cast<double *>(trackedAllocate(values * sizeof(double)));
      if (!output->lengths || !output->values) {
        ct_free(output);
        return output->status = 3;
      }
      size_t offset = 0;
      for (size_t i = 0; i < contours.size(); i++) {
        output->lengths[i] = uint32_t(contours[i].size());
        std::memcpy(output->values + offset, contours[i].data(),
                    contours[i].size() * sizeof(double));
        offset += contours[i].size();
      }
    }
    output->count = uint32_t(contours.size());
    output->value_count = values;
    return 0;
  } catch (...) {
    ct_free(output);
    return output->status = 3;
  }
}
}
