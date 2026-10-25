# Native compositor provenance

The Gaussian blur implementation is adapted from Skia revision
`8df24be66531469e576a806749a0202ae26b8d08`:

- [SkMaskBlurFilter.cpp](https://github.com/google/skia/blob/8df24be66531469e576a806749a0202ae26b8d08/src/core/SkMaskBlurFilter.cpp)
- [SkGaussFilter.cpp](https://github.com/google/skia/blob/8df24be66531469e576a806749a0202ae26b8d08/src/core/SkGaussFilter.cpp)

The Google LLC BSD license is retained in `SKIA_LICENSE` and the adapted
headers. This code is compiled into the package and does not require a custom
Flutter engine or an external Skia library.

Package adaptations compose A8 coverage directly into a strided premultiplied
RGBA destination. They retain the scalar small-sigma kernels, filter support,
coefficient rounding, and horizontal-A8-vertical pass order. Zero A8 margins
are cropped before filtering. Integer-placement source-over uses eight NEON
lanes where available; the vertical Gaussian pass also processes eight columns
together while horizontal rows remain contiguous.

When replacing the destination, zero shadows or one shadow with an integral
offset use a single write-only pass. The contour and shadow may have any ARGB
color or opacity. Fractional offsets and multiple shadows use the general
source-over path. Both paths preserve the same input visibility and geometry;
this compositor adds no alpha thresholds.

Scratch belongs to one worker and must not be used concurrently. Output bounds
include the actual blur support and offset padding, and only the declared RGBA
row span is written.
