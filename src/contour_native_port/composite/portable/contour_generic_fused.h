#ifndef CONTOUR_GENERIC_FUSED_H
#define CONTOUR_GENERIC_FUSED_H
#include "contour_a8_compositor.h"
#include "contour_backing_raster.h"
#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>
namespace contour_generic {
enum class Status { ok, empty, unsupported, cancelled, invalid, capacity, failed };
struct Request {
  const uint8_t *source = nullptr;
  std::size_t source_length = 0, source_stride = 0;
  uint32_t width = 0, height = 0;
  bool rgba = false;
  double source_ratio = 1, output_ratio = 1, amount = 0;
  uint32_t contour_argb = 0xffffffff;
  const contour_a8::Shadow *shadows = nullptr;
  std::size_t shadow_count = 0;
  uint64_t allocation_limit = 64ULL * 1024 * 1024, trace_limit = 16ULL * 1024 * 1024;
  int output_pixel_limit = 1024 * 1024;
};
struct Metrics {
  int64_t source_copy_wall_ns = 0, source_copy_cpu_ns = 0;
  int64_t trace_wall_ns = 0, trace_cpu_ns = 0;
  int64_t curve_scale_wall_ns = 0, curve_scale_cpu_ns = 0;
  int64_t backing_wall_ns = 0, backing_cpu_ns = 0;
  int64_t composition_wall_ns = 0, composition_cpu_ns = 0;
  int64_t total_wall_ns = 0, total_cpu_ns = 0;
  uint64_t trace_peak_bytes = 0, known_capacity_peak_bytes = 0;
  uint64_t source_pixels = 0, backing_pixels = 0, output_pixels = 0, curve_coordinates = 0;
  std::array<int64_t, 36> backing{};
};
struct Output {
  Status status = Status::failed;
  std::string error;
  std::vector<uint8_t> rgba;
  int width = 0, height = 0;
  // Physical capture-local origin; consumers add capture origin, then divide by ratio.
  double left = 0, top = 0;
  Metrics metrics;
};
struct Scratch {
  std::vector<uint8_t> source_alpha;
  std::vector<std::vector<double>> curves;
  contour_backing::Output backing;
  contour_a8::Scratch compositor;
};
using CancelFn = int32_t (*)(void *);
// One serial synchronous call. Borrows source, shadows and cancellation context.
// Backing geometry is the accepted portable AA8 implementation; visibility/fitting
// are the unchanged .03/.25 trace kernel. Output is premultiplied RGBA8888.
// Amount below .5 physical pixels is declined for the caller's qualified fallback.
// Cancellation is polled between stages and by the backing kernel; source tracing
// and the compositor run to completion within their admitted resource bounds.
Status render(const Request &, Output &, Scratch &, CancelFn = nullptr,
              void *cancel_user = nullptr);
}
#endif
