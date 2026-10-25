#ifndef CONTOUR_BACKING_RASTER_H
#define CONTOUR_BACKING_RASTER_H

#include <array>
#include <cstdint>
#include <string>
#include <vector>

namespace contour_backing {
using Curves = std::vector<std::vector<double>>;
using CancelFn = int32_t (*)(void *);
enum class Status { ok, unsupported, cancelled, capacity, invalid, failed };
struct Limits {
  int output_pixel_limit = 1024 * 1024;
  std::uint64_t allocation_limit = 64ULL * 1024 * 1024;
  int pad_left = 0, pad_top = 0, pad_right = 0, pad_bottom = 0;
};
struct Output {
  Status status = Status::failed;
  std::string error;
  std::vector<std::uint8_t> alpha;
  int width = 0, height = 0;
  double left = 0, top = 0;
  // Same indices as the accepted JNI wrapper; timings exclude Java copying.
  std::array<std::int64_t, 36> metrics{};
};
// Borrows physical MOVE+six-values-per-cubic EvenOdd loops only during this call.
// Amounts below .5 return unsupported; the caller must use its qualified fill path.
// Cancellation may not interrupt Clipper calls. Partial failed masks are discarded.
// The caller owns callback context through return and may reuse Output on later calls.
Status render(const Curves &input, double amount, Output &output, const Limits &limits = {},
              CancelFn cancel = nullptr, void *cancel_user = nullptr);
} // namespace contour_backing
#endif
