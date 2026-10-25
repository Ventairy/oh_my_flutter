#include "contour_a8_compositor.h"
#include "skia_plan_gauss.h"
#include "skia_neon_blur.h"
#include "small_sigma_blur.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#if defined(__ARM_NEON)
#include <arm_neon.h>
#endif
namespace contour_a8 {
namespace {
uint8_t mul255(unsigned a, unsigned b) {
  unsigned v = a * b + 128;
  return static_cast<uint8_t>((v + (v >> 8)) >> 8);
}
void pixel_over(uint8_t *dst, uint8_t coverage, uint32_t color) {
  const unsigned a = mul255(coverage, color >> 24);
  if (!a)
    return;
  const unsigned inv = 255 - a;
  dst[0] = static_cast<uint8_t>(mul255((color >> 16) & 255, a) + mul255(dst[0], inv));
  dst[1] = static_cast<uint8_t>(mul255((color >> 8) & 255, a) + mul255(dst[1], inv));
  dst[2] = static_cast<uint8_t>(mul255(color & 255, a) + mul255(dst[2], inv));
  dst[3] = static_cast<uint8_t>(a + mul255(dst[3], inv));
}
#if defined(__ARM_NEON)
uint8x8_t mul255_neon(uint8x8_t a, uint8x8_t b) {
  uint16x8_t v = vaddq_u16(vmull_u8(a, b), vdupq_n_u16(128));
  return vshrn_n_u16(vaddq_u16(v, vshrq_n_u16(v, 8)), 8);
}
void span_over_neon(uint8_t *dst, const uint8_t *coverage, int count, uint32_t color) {
  const uint8x8_t ca = vdup_n_u8(color >> 24), cr = vdup_n_u8((color >> 16) & 255),
                  cg = vdup_n_u8((color >> 8) & 255), cb = vdup_n_u8(color & 255);
  int i = 0;
  for (; i + 8 <= count; i += 8, dst += 32, coverage += 8) {
    const uint8x8_t a = mul255_neon(vld1_u8(coverage), ca), inv = vmvn_u8(a);
    uint8x8x4_t d = vld4_u8(dst);
    d.val[0] = vadd_u8(mul255_neon(cr, a), mul255_neon(d.val[0], inv));
    d.val[1] = vadd_u8(mul255_neon(cg, a), mul255_neon(d.val[1], inv));
    d.val[2] = vadd_u8(mul255_neon(cb, a), mul255_neon(d.val[2], inv));
    d.val[3] = vadd_u8(a, mul255_neon(d.val[3], inv));
    vst4_u8(dst, d);
  }
  for (; i < count; i++, dst += 4, coverage++)
    pixel_over(dst, *coverage, color);
}
#endif
void paint(const uint8_t *src, int sw, int sh, size_t stride, float dx, float dy, uint32_t color,
           uint8_t *dst, int dw, int dh, size_t dst_stride) {
  if (dx <= -sw || dx >= dw || dy <= -sh || dy >= dh)
    return;
  const int ix = static_cast<int>(std::floor(dx)), iy = static_cast<int>(std::floor(dy));
  const double fx = dx - ix, fy = dy - iy;
  if (fx == 0 && fy == 0) {
    const int x0 = std::max(0, ix), x1 = std::min(dw, ix + sw), y0 = std::max(0, iy),
              y1 = std::min(dh, iy + sh);
    for (int y = y0; y < y1; y++) {
      auto *out = dst + size_t(y) * dst_stride + size_t(x0) * 4;
      const auto *in = src + size_t(y - iy) * stride + (x0 - ix);
#if defined(__ARM_NEON)
      span_over_neon(out, in, std::max(0, x1 - x0), color);
#else
      for (int x = x0; x < x1; x++, out += 4, in++)
        pixel_over(out, *in, color);
#endif
    }
  } else {
    const int x0 = std::max(0, ix), x1 = std::min(dw, ix + sw + 1), y0 = std::max(0, iy),
              y1 = std::min(dh, iy + sh + 1);
    auto sample = [&](int x, int y) -> unsigned {
      return x >= 0 && x < sw && y >= 0 && y < sh ? src[size_t(y) * stride + x] : 0;
    };
    for (int y = y0; y < y1; y++) {
      auto *out = dst + size_t(y) * dst_stride + size_t(x0) * 4;
      int sy = y - iy;
      for (int x = x0; x < x1; x++, out += 4) {
        int sx = x - ix;
        double a = sample(sx, sy) * (1 - fx) * (1 - fy) + sample(sx - 1, sy) * fx * (1 - fy) +
                   sample(sx, sy - 1) * (1 - fx) * fy + sample(sx - 1, sy - 1) * fx * fy;
        pixel_over(out, static_cast<uint8_t>(std::floor(a + 0.5)), color);
      }
    }
  }
}
int gaussian_small(const uint8_t *src, int w, int h, size_t stride, float sigma, Scratch &scratch) {
  const auto kernel = contour_small_sigma::make_kernel(sigma);
  contour_small_sigma::blur(src, w, h, stride, kernel, scratch.temporary, scratch.blurred);
  return kernel.radius;
}

int blur(const uint8_t *src, int w, int h, size_t stride, float sigma, Scratch &scratch) {
  if (sigma < 2)
    return gaussian_small(src, w, h, stride, sigma, scratch);
  return internal::blur_sigma_ge2(src, w, h, stride, sigma, scratch.temporary, scratch.blurred,
                                  scratch.ring);
}
}
#if defined(__ARM_NEON)
uint8x8_t coverage8(const uint8_t *row, int width, int x) {
  if (!row)
    return vdup_n_u8(0);
  if (x >= 0 && x + 8 <= width)
    return vld1_u8(row + x);
  uint8_t tail[8];
  for (int i = 0; i < 8; i++)
    tail[i] = x + i >= 0 && x + i < width ? row[x + i] : 0;
  return vld1_u8(tail);
}
#endif
void single_shadow_writeonly(const uint8_t *alpha, int w, int h, size_t astride, uint32_t color,
                             const Shadow &shadow, uint8_t *dst, int dw, int dh, size_t stride,
                             int sx, int sy, int left, int top, int right, int bottom,
                             Scratch &scratch) {
  const uint8_t *blurred = alpha;
  int bw = w, bh = h;
  size_t bstride = astride;
  int bx = sx + static_cast<int>(shadow.dx), by = sy + static_cast<int>(shadow.dy);
  if (shadow.sigma > .5f && (shadow.argb >> 24)) {
    int r = blur(alpha + size_t(top) * astride + left, right - left, bottom - top, astride,
                 shadow.sigma, scratch);
    blurred = scratch.blurred.data();
    bw = right - left + 2 * r;
    bh = bottom - top + 2 * r;
    bstride = bw;
    bx += left - r;
    by += top - r;
  }
  const unsigned ca = color >> 24, cr = (color >> 16) & 255, cg = (color >> 8) & 255,
                 cb = color & 255, sa = shadow.argb >> 24, sr = (shadow.argb >> 16) & 255,
                 sg = (shadow.argb >> 8) & 255, sb = shadow.argb & 255;
  const bool colored_shadow = (shadow.argb & 0xffffffu) != 0;
  for (int y = 0; y < dh; y++) {
    auto *out = dst + size_t(y) * stride;
    const uint8_t *crow = y - sy >= 0 && y - sy < h ? alpha + size_t(y - sy) * astride : nullptr;
    const uint8_t *brow =
        sa && y - by >= 0 && y - by < bh ? blurred + size_t(y - by) * bstride : nullptr;
    int x = 0;
#if defined(__ARM_NEON)
    for (; x + 8 <= dw; x += 8, out += 32) {
      const auto a = mul255_neon(coverage8(crow, w, x - sx), vdup_n_u8(ca));
      const auto b = mul255_neon(coverage8(brow, bw, x - bx), vdup_n_u8(sa));
      uint8x8x4_t result;
      result.val[0] = mul255_neon(a, vdup_n_u8(cr));
      result.val[1] = mul255_neon(a, vdup_n_u8(cg));
      result.val[2] = mul255_neon(a, vdup_n_u8(cb));
      if (colored_shadow) {
        const auto inv = vmvn_u8(a);
        result.val[0] = vadd_u8(result.val[0], mul255_neon(mul255_neon(b, vdup_n_u8(sr)), inv));
        result.val[1] = vadd_u8(result.val[1], mul255_neon(mul255_neon(b, vdup_n_u8(sg)), inv));
        result.val[2] = vadd_u8(result.val[2], mul255_neon(mul255_neon(b, vdup_n_u8(sb)), inv));
      }
      result.val[3] = vadd_u8(a, mul255_neon(b, vmvn_u8(a)));
      vst4_u8(out, result);
    }
#endif
    for (; x < dw; x++, out += 4) {
      const unsigned a = mul255(crow && x - sx >= 0 && x - sx < w ? crow[x - sx] : 0, ca);
      const unsigned b = mul255(brow && x - bx >= 0 && x - bx < bw ? brow[x - bx] : 0, sa);
      out[0] = static_cast<uint8_t>(mul255(a, cr) + mul255(mul255(b, sr), 255 - a));
      out[1] = static_cast<uint8_t>(mul255(a, cg) + mul255(mul255(b, sg), 255 - a));
      out[2] = static_cast<uint8_t>(mul255(a, cb) + mul255(mul255(b, sb), 255 - a));
      out[3] = static_cast<uint8_t>(a + mul255(b, 255 - a));
    }
  }
}

int blur_support(float sigma) {
  if (!std::isfinite(sigma) || sigma < 0 || sigma > 128)
    return -1;
  if (sigma <= .5f)
    return 0;
  if (sigma >= 2)
    return internal::PlanGauss(sigma).border();
  return contour_small_sigma::make_kernel(sigma).radius;
}
bool compose_placed(const uint8_t *alpha, int w, int h, size_t astride, uint32_t color,
                    const Shadow *shadows, size_t count, uint8_t *dst, int dw, int dh,
                    size_t stride, size_t capacity, int source_x, int source_y, Scratch &scratch,
                    bool clear) {
  if (!alpha || !dst || w < 1 || h < 1 || w > 2048 || h > 2048 || size_t(w) * h > 1048576 ||
      dw < 1 || dh < 1 || dw > 2048 || dh > 2048 || size_t(dw) * dh > 1048576 ||
      astride < size_t(w) || stride < size_t(dw) * 4 ||
      capacity < size_t(dh - 1) * stride + size_t(dw) * 4 || count > 4 || (!shadows && count))
    return false;
  for (size_t i = 0; i < count; i++)
    if (blur_support(shadows[i].sigma) < 0 || !std::isfinite(shadows[i].dx) ||
        !std::isfinite(shadows[i].dy))
      return false;
  int left = w, top = h, right = 0, bottom = 0;
  for (int y = 0; y < h; y++) {
    const auto *row = alpha + size_t(y) * astride;
    int first = 0, last = w;
    while (first < last && !row[first])
      ++first;
    while (last > first && !row[last - 1])
      --last;
    if (first < last) {
      left = std::min(left, first);
      right = std::max(right, last);
      top = std::min(top, y);
      bottom = y + 1;
    }
  }
  if (left >= right) {
    if (clear)
      for (int y = 0; y < dh; y++)
        std::memset(dst + size_t(y) * stride, 0, size_t(dw) * 4);
    return true;
  }
  const bool single_shadow =
      clear && (count == 0 || (count == 1 && std::floor(shadows[0].dx) == shadows[0].dx &&
                               std::floor(shadows[0].dy) == shadows[0].dy &&
                               std::abs(shadows[0].dx) <= 8192 && std::abs(shadows[0].dy) <= 8192));
  if (single_shadow) {
    const Shadow invisible{0, 0, 0, 0};
    single_shadow_writeonly(alpha, w, h, astride, color, count ? shadows[0] : invisible, dst, dw,
                            dh, stride, source_x, source_y, left, top, right, bottom, scratch);
    return true;
  }
  if (clear)
    for (int y = 0; y < dh; y++)
      std::memset(dst + size_t(y) * stride, 0, size_t(dw) * 4);
  for (size_t i = 0; i < count; i++) {
    const auto &s = shadows[i];
    if (!(s.argb >> 24))
      continue;
    if (s.sigma <= .5f)
      paint(alpha, w, h, astride, s.dx + source_x, s.dy + source_y, s.argb, dst, dw, dh, stride);
    else {
      int r = blur(alpha + size_t(top) * astride + left, right - left, bottom - top, astride,
                   s.sigma, scratch);
      paint(scratch.blurred.data(), right - left + 2 * r, bottom - top + 2 * r,
            right - left + 2 * r, s.dx + left - r + source_x, s.dy + top - r + source_y, s.argb,
            dst, dw, dh, stride);
    }
  }
  paint(alpha, w, h, astride, source_x, source_y, color, dst, dw, dh, stride);
  return true;
}
bool padding_bounds(int w, int h, const Shadow *shadows, size_t count, Bounds &result) {
  if (w < 1 || h < 1 || w > 2048 || h > 2048 || size_t(w) * h > 1048576 || count > 4 ||
      (!shadows && count))
    return false;
  double left = 0, top = 0, right = w, bottom = h;
  for (size_t i = 0; i < count; i++) {
    const auto &s = shadows[i];
    int r = blur_support(s.sigma);
    if (r < 0 || !std::isfinite(s.dx) || !std::isfinite(s.dy))
      return false;
    if (!(s.argb >> 24))
      continue;
    left = std::min(left, std::floor(double(s.dx)) - r);
    top = std::min(top, std::floor(double(s.dy)) - r);
    right = std::max(right, std::ceil(double(s.dx)) + w + r);
    bottom = std::max(bottom, std::ceil(double(s.dy)) + h + r);
  }
  if (right - left > 2048 || bottom - top > 2048 || (right - left) * (bottom - top) > 1048576)
    return false;
  result = {static_cast<int>(left), static_cast<int>(top), static_cast<int>(right - left),
            static_cast<int>(bottom - top)};
  return true;
}
bool compose_padded(const uint8_t *alpha, int w, int h, size_t astride, uint32_t color,
                    const Shadow *shadows, size_t count, uint8_t *dst, size_t stride,
                    size_t capacity, const Bounds &bounds, Scratch &scratch, bool clear) {
  Bounds expected;
  if (!padding_bounds(w, h, shadows, count, expected) || bounds.left != expected.left ||
      bounds.top != expected.top || bounds.width != expected.width ||
      bounds.height != expected.height)
    return false;
  return compose_placed(alpha, w, h, astride, color, shadows, count, dst, bounds.width,
                        bounds.height, stride, capacity, -bounds.left, -bounds.top, scratch, clear);
}
}
