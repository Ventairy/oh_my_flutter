#pragma once
#include <array>
#include <cstdint>
#include <string>
#include <vector>
#include "portable/contour_generic_fused.h"
namespace contour_cpu {
struct Tile {
  uint32_t x = 0, y = 0, width = 0, height = 0;
  double source_ratio = 1, output_ratio = 1, amount = 0;
  uint32_t contour_argb = 0xffffffff;
  std::array<contour_a8::Shadow, 4> shadows{};
  size_t shadow_count = 0;
};
struct Request {
  const uint8_t *rgba = nullptr;
  size_t length = 0, stride = 0;
  uint32_t width = 0, height = 0;
  const Tile *tiles = nullptr;
  size_t count = 0;
  uint64_t allocation_limit = 64ULL * 1024 * 1024;
  uint32_t atlas_width = 1024, atlas_pixel_limit = 4 * 1024 * 1024, workers = 1, gutter = 2;
};
struct Placement {
  int x = 0, y = 0, width = 0, height = 0;
  double left = 0, top = 0;
};
struct Metrics {
  int64_t wall_ns = 0, cpu_sum_ns = 0, pack_cpu_ns = 0;
  uint64_t source_rgba_bytes = 0, output_rgba_bytes = 0, known_peak_bytes = 0;
  int64_t trace_cpu_ns = 0, backing_cpu_ns = 0, composition_cpu_ns = 0;
  uint32_t active_peak = 0;
  int64_t dedup_cpu_ns = 0;
};
struct Output {
  contour_generic::Status status = contour_generic::Status::failed;
  std::string error;
  std::vector<uint8_t> rgba;
  std::vector<Placement> placements;
  uint32_t width = 0, height = 0;
  Metrics metrics;
};
contour_generic::Status render(const Request &, Output &, contour_generic::CancelFn = nullptr,
                               void *cancel_user = nullptr);
}
