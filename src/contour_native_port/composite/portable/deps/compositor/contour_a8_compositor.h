#pragma once
#include <cstddef>
#include <cstdint>
#include <vector>
namespace contour_a8 {
struct Shadow {
  float sigma, dx, dy;
  uint32_t argb;
};
struct Scratch {
  std::vector<uint8_t> temporary, blurred;
  std::vector<uint32_t> ring;
};
struct Bounds {
  int left, top, width, height;
};
// Tight A8 input support plus all shadow filters and fractional translations.
// Result origin is relative to input; caller allocates bounds.width*height RGBA.
bool padding_bounds(int width, int height, const Shadow *, size_t shadow_count, Bounds &);
bool compose_padded(const uint8_t *, int width, int height, size_t alpha_stride,
                    uint32_t contour_argb, const Shadow *, size_t shadow_count, uint8_t *rgba,
                    size_t rgba_stride, size_t rgba_capacity, const Bounds &, Scratch &,
                    bool clear = true);
int blur_support(float sigma);
}
