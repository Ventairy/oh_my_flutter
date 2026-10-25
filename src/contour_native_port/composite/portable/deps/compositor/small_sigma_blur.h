/*
 * Copyright 2017 Google LLC
 *
 * Scalar adaptation of SkGaussFilter.cpp and SkMaskBlurFilter.cpp from Skia.
 * Use of this source code is governed by the BSD-style license in SKIA_LICENSE.
 */
#pragma once

#include <algorithm>
#include <array>
#include <cassert>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace contour_small_sigma {

struct Kernel {
  int radius;
  std::array<uint16_t, 6> factors{};
};

// Same Bessel recurrence, support truncation, normalization and coefficient
// rounding as pinned Skia SkGaussFilter. Call ONLY for 0.5 < sigma < 2.0.
inline Kernel make_kernel(double sigma) {
  assert(sigma > 0.5 && sigma < 2.0);
  const double var = sigma * sigma;
  const double t_squared_over_4 = var * var / 4.0;
  double b[6]{};
  double g[6]{};
  double factor = 1.0;
  b[0] = 1.0;
  for (int k = 1; factor > 1.0 / 1000000.0; ++k) {
    factor *= t_squared_over_4 / (k * k);
    b[0] += factor;
  }
  factor = var / 2.0;
  b[1] = factor;
  for (int k = 1; factor > 1.0 / 1000000.0; ++k) {
    factor *= t_squared_over_4 / (k * (k + 1));
    b[1] += factor;
  }
  const double d = std::exp(var);
  g[0] = b[0] / d;
  g[1] = b[1] / d;
  int n = 1;
  while (g[n] > 0.01) {
    b[n + 1] = -(2 * n / var) * b[n] + b[n - 1];
    g[n + 1] = b[n + 1] / d;
    ++n;
  }
  double sum = 0.0;
  for (int i = n - 1; i >= 1; --i) sum += 2.0 * g[i];
  sum += g[0];
  for (int i = 0; i < n; ++i) g[i] /= sum;
  sum = 0.0;
  for (int i = n - 1; i >= 1; --i) sum += 2.0 * g[i];
  g[0] = 1.0 - sum;
  Kernel kernel{n - 1};
  for (int i = 0; i < n; ++i) {
    kernel.factors[i] = static_cast<uint16_t>(std::round(g[i] * 65536.0));
  }
  return kernel;
}

// Equivalent to mulhi(sourceA8 << 8, coefficientQ0_16). Truncate EACH
// contribution before summing; rounding only the full weighted sum differs.
inline uint32_t contribution(uint8_t source, uint16_t coefficient) {
  return (static_cast<uint32_t>(source) * coefficient) >> 8;
}

// Full zero-extended output. Output (0,0) is source (-radius,-radius).
// Source stride may be larger than width. Destination is tightly packed.
// Vertical -> A8 -> horizontal -> A8 order is observable and matches Skia.
inline void blur(const uint8_t* source, int width, int height,
                                 size_t source_stride, const Kernel& kernel,
                                 std::vector<uint8_t>& vertical, std::vector<uint8_t>& result) {
  assert(source && width > 0 && height > 0);
  assert(source_stride >= static_cast<size_t>(width));
  assert(kernel.radius >= 1 && kernel.radius <= 4);
  const int radius = kernel.radius;
  const int out_width = width + 2 * radius;
  const int out_height = height + 2 * radius;
  // Horizontal reads only source-width center columns, so this temporary can
  // avoid the zero left/right padding allocated by Skia's in-place version.
  vertical.resize(static_cast<size_t>(width) * out_height);
  result.resize(static_cast<size_t>(out_width) * out_height);
  for (int y = 0; y < out_height; ++y) {
    const int first = std::max(-radius, radius - y);
    const int last = std::min(radius, height - 1 + radius - y);
    for (int x = 0; x < width; ++x) {
      uint32_t sum = 128;
      for (int k = first; k <= last; ++k) {
        sum += contribution(source[(y - radius + k) * source_stride + x],
                            kernel.factors[std::abs(k)]);
      }
      vertical[static_cast<size_t>(y) * width + x] = static_cast<uint8_t>(sum >> 8);
    }
  }
  for (int y = 0; y < out_height; ++y) {
    const uint8_t* row = vertical.data() + static_cast<size_t>(y) * width;
    for (int x = 0; x < out_width; ++x) {
      const int first = std::max(-radius, radius - x);
      const int last = std::min(radius, width - 1 + radius - x);
      uint32_t sum = 128;
      for (int k = first; k <= last; ++k) {
        sum += contribution(row[x - radius + k], kernel.factors[std::abs(k)]);
      }
      result[static_cast<size_t>(y) * out_width + x] = static_cast<uint8_t>(sum >> 8);
    }
  }
}

}  // namespace contour_small_sigma
