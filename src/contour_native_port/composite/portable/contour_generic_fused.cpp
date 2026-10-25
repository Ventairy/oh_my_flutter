#include "contour_generic_fused.h"
#include "contour_source_a8.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <new>
#include <time.h>
namespace contour_generic {
namespace {
int64_t now(clockid_t clock) {
  timespec t{};
  clock_gettime(clock, &t);
  return int64_t(t.tv_sec) * 1000000000 + t.tv_nsec;
}
struct Stamp {
  int64_t wall = now(CLOCK_MONOTONIC), cpu = now(CLOCK_THREAD_CPUTIME_ID);
};
void elapsed(const Stamp &stamp, int64_t &wall, int64_t &cpu) {
  wall = now(CLOCK_MONOTONIC) - stamp.wall;
  cpu = now(CLOCK_THREAD_CPUTIME_ID) - stamp.cpu;
}
uint64_t curve_bytes(const Scratch &s) {
  uint64_t bytes = s.curves.capacity() * sizeof(std::vector<double>);
  for (const auto &c : s.curves)
    bytes += c.capacity() * sizeof(double);
  return bytes;
}
uint64_t scratch_bytes(const Scratch &s) {
  return s.source_alpha.capacity() + curve_bytes(s) + s.backing.alpha.capacity() +
         s.compositor.temporary.capacity() +
         s.compositor.blurred.capacity() + s.compositor.ring.capacity() * sizeof(uint32_t);
}
Status fail(Output &out, Status status, const char *error) {
  out.status = status;
  out.error = error;
  out.rgba.clear();
  out.width = out.height = 0;
  out.left = out.top = 0;
  return status;
}
Status map(contour_backing::Status status) {
  switch (status) {
  case contour_backing::Status::ok:
    return Status::ok;
  case contour_backing::Status::unsupported:
    return Status::unsupported;
  case contour_backing::Status::cancelled:
    return Status::cancelled;
  case contour_backing::Status::capacity:
    return Status::capacity;
  case contour_backing::Status::invalid:
    return Status::invalid;
  case contour_backing::Status::failed:
    return Status::failed;
  }
  return Status::failed;
}
}
Status render(const Request &request, Output &output, Scratch &scratch, CancelFn cancel,
              void *cancel_user) {
  const Stamp total;
  output.status = Status::failed;
  output.error.clear();
  output.rgba.clear();
  output.width = output.height = 0;
  output.left = output.top = 0;
  output.metrics = {};
  auto finish = [&](Status status) {
    output.status = status;
    elapsed(total, output.metrics.total_wall_ns, output.metrics.total_cpu_ns);
    return status;
  };
  auto cancelled = [&]() { return cancel && cancel(cancel_user) != 0; };
  try {
    if (!request.source || !request.width || !request.height || request.width > 2048 ||
        request.height > 2048 || uint64_t(request.width) * request.height > 1024 * 1024 ||
        !std::isfinite(request.source_ratio) || request.source_ratio <= 0 ||
        !std::isfinite(request.output_ratio) || request.output_ratio <= 0 ||
        !std::isfinite(request.amount) || request.amount < 0 || request.output_pixel_limit < 1 ||
        request.output_pixel_limit > 1024 * 1024 || request.allocation_limit < 1024 ||
        request.allocation_limit > 64ULL * 1024 * 1024 || request.trace_limit < 1024 ||
        request.trace_limit > request.allocation_limit || request.shadow_count > 4 ||
        (!request.shadows && request.shadow_count))
      return finish(fail(output, Status::invalid, "Unsupported source or resource bounds"));
    if (request.amount < .5)
      return finish(fail(output, Status::unsupported,
                         "Sub-.5 physical contour requires the existing qualified fill fallback"));
    const uint64_t pixel_stride = request.rgba ? 4 : 1,
                   min_stride = uint64_t(request.width) * pixel_stride;
    if (request.source_stride < min_stride ||
        request.source_stride > std::numeric_limits<uint64_t>::max() / request.height ||
        uint64_t(request.height - 1) * request.source_stride + min_stride > request.source_length)
      return finish(fail(output, Status::invalid, "Source byte length or stride is insufficient"));
    for (std::size_t i = 0; i < request.shadow_count; ++i) {
      const auto &shadow = request.shadows[i];
      if (contour_a8::blur_support(shadow.sigma) < 0 || !std::isfinite(shadow.dx) ||
          !std::isfinite(shadow.dy))
        return finish(fail(output, Status::unsupported, "Unsupported shadow sigma or translation"));
    }
    if (cancelled())
      return finish(fail(output, Status::cancelled, "Cancelled before source tracing"));
    output.metrics.source_pixels = uint64_t(request.width) * request.height;
    const uint64_t before_copy = scratch_bytes(scratch) + output.rgba.capacity();
    if (before_copy > request.allocation_limit ||
        output.metrics.source_pixels > request.allocation_limit - before_copy)
      return finish(fail(output, Status::capacity, "Source packing exceeds active admission"));
    const uint8_t *alpha = request.source;
    if (request.rgba || request.source_stride != request.width) {
      const Stamp copy;
      scratch.source_alpha.resize(output.metrics.source_pixels);
      for (uint32_t y = 0; y < request.height; ++y)
        for (uint32_t x = 0; x < request.width; ++x)
          scratch.source_alpha[uint64_t(y) * request.width + x] =
              request.source[uint64_t(y) * request.source_stride + uint64_t(x) * pixel_stride +
                             (request.rgba ? 3 : 0)];
      alpha = scratch.source_alpha.data();
      elapsed(copy, output.metrics.source_copy_wall_ns, output.metrics.source_copy_cpu_ns);
    }
    const uint64_t before_trace = scratch_bytes(scratch) + output.rgba.capacity();
    if (before_trace >= request.allocation_limit)
      return finish(
          fail(output, Status::capacity, "Retained fused buffers exhaust source admission"));
    const uint64_t trace_budget =
        std::min(request.trace_limit, request.allocation_limit - before_trace);
    const Stamp tracing;
    const int traced =
        contour_source::traceA8(alpha, request.width, request.height, request.source_ratio,
                                trace_budget, scratch.curves, &output.metrics.trace_peak_bytes);
    elapsed(tracing, output.metrics.trace_wall_ns, output.metrics.trace_cpu_ns);
    if (traced)
      return finish(fail(output, traced == 2 ? Status::invalid : Status::capacity,
                         "Source trace declined its admitted geometry or working capacity"));
    if (cancelled())
      return finish(fail(output, Status::cancelled, "Cancelled after source tracing"));
    output.metrics.known_capacity_peak_bytes =
        std::max(before_trace + output.metrics.trace_peak_bytes,
                 scratch_bytes(scratch) + output.rgba.capacity());
    if (scratch.curves.empty())
      return finish(Status::empty);
    for (const auto &curve : scratch.curves)
      output.metrics.curve_coordinates += curve.size();
    if (request.source_ratio != request.output_ratio) {
      const Stamp scaling;
      const double scale = request.output_ratio / request.source_ratio;
      for (auto &curve : scratch.curves)
        for (auto &coordinate : curve)
          coordinate *= scale;
      elapsed(scaling, output.metrics.curve_scale_wall_ns, output.metrics.curve_scale_cpu_ns);
    }
    const uint64_t retained = scratch_bytes(scratch) + output.rgba.capacity();
    if (retained >= request.allocation_limit)
      return finish(
          fail(output, Status::capacity, "Retained source storage exhausts active admission"));
    contour_backing::Limits limits;
    limits.output_pixel_limit = request.output_pixel_limit;
    limits.allocation_limit = request.allocation_limit - retained;
    // Keep shadow padding out of geometric AA8 work. Composition adds its actual
    // filter support later and returns the adjusted physical origin.
    const Stamp backing;
    const auto rendered = contour_backing::render(scratch.curves, request.amount, scratch.backing,
                                                  limits, cancel, cancel_user);
    elapsed(backing, output.metrics.backing_wall_ns, output.metrics.backing_cpu_ns);
    output.metrics.backing = scratch.backing.metrics;
    if (rendered != contour_backing::Status::ok)
      return finish(fail(output, map(rendered), scratch.backing.error.c_str()));
    output.metrics.backing_pixels = scratch.backing.alpha.size();
    output.metrics.known_capacity_peak_bytes =
        std::max(output.metrics.known_capacity_peak_bytes,
                 retained + uint64_t(std::max<int64_t>(0, scratch.backing.metrics[35])));
    if (cancelled())
      return finish(fail(output, Status::cancelled, "Cancelled before shadow composition"));
    contour_a8::Bounds bounds;
    if (!contour_a8::padding_bounds(scratch.backing.width, scratch.backing.height, request.shadows,
                                    request.shadow_count, bounds) ||
        uint64_t(bounds.width) * bounds.height > uint64_t(request.output_pixel_limit))
      return finish(
          fail(output, Status::capacity, "Padded decoration exceeds its output capacity"));
    output.metrics.output_pixels = uint64_t(bounds.width) * bounds.height;
    uint64_t maximum_blur = 0;
    for (std::size_t i = 0; i < request.shadow_count; ++i) {
      if (!(request.shadows[i].argb >> 24))
        continue;
      const uint64_t radius = contour_a8::blur_support(request.shadows[i].sigma),
                     w = uint64_t(scratch.backing.width) + 2 * radius,
                     h = uint64_t(scratch.backing.height) + 2 * radius;
      maximum_blur = std::max(maximum_blur, w * scratch.backing.height + w * h + (radius + 1) * 32);
    }
    const uint64_t known = scratch_bytes(scratch), reserved = output.rgba.capacity(),
                   new_output = output.metrics.output_pixels * 4;
    if (known > request.allocation_limit || maximum_blur > (request.allocation_limit - known) / 2 ||
        std::max(reserved, new_output) > (request.allocation_limit - known - maximum_blur * 2) / 2)
      return finish(fail(output, Status::capacity,
                         "Native RGBA and compositor working buffers exceed active admission"));
    const Stamp composition;
    output.rgba.resize(new_output);
    if (!contour_a8::compose_padded(scratch.backing.alpha.data(), scratch.backing.width,
                                    scratch.backing.height, scratch.backing.width,
                                    request.contour_argb, request.shadows, request.shadow_count,
                                    output.rgba.data(), uint64_t(bounds.width) * 4,
                                    output.rgba.size(), bounds, scratch.compositor))
      return finish(fail(output, Status::failed, "Native A8 compositor declined admitted input"));
    elapsed(composition, output.metrics.composition_wall_ns, output.metrics.composition_cpu_ns);
    output.width = bounds.width;
    output.height = bounds.height;
    output.left = scratch.backing.left + bounds.left;
    output.top = scratch.backing.top + bounds.top;
    output.metrics.known_capacity_peak_bytes = std::max(
        output.metrics.known_capacity_peak_bytes, scratch_bytes(scratch) + output.rgba.capacity());
    if (cancelled())
      return finish(fail(output, Status::cancelled, "Cancelled after native composition"));
    return finish(Status::ok);
  } catch (const std::bad_alloc &) {
    return finish(fail(output, Status::capacity, "Native fused allocation failed"));
  } catch (...) {
    return finish(fail(output, Status::failed, "Native fused job failed"));
  }
}
}
