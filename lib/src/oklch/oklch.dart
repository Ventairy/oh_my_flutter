import 'dart:math' as math;
import 'dart:ui' show ColorSpace;

import 'package:flutter/material.dart';

part '_oklch_converter.dart';

/// An OKLCH color representation (lightness, chroma, hue).
///
/// OKLCH is a perceptually uniform color space where equal steps in
/// lightness _look_ equal. It is the modern standard for building color
/// systems (used by Tailwind v4, Radix UI, Stripe, and others).
///
/// ```dart
/// final oklch = Color(0xFFFF4A4B).toOklch;
/// print(oklch.l); // 0.65 (lightness)
/// print(oklch.c); // 0.23 (chroma)
/// print(oklch.h); // 28.0 (hue in degrees)
///
/// final color = oklch.toColor();
/// ```
@immutable
final class Oklch {
  /// Creates an opaque OKLCH color.
  ///
  /// Alpha is intentionally outside this value type's scope.
  const Oklch(this.l, this.c, this.h);

  /// Lightness in the inclusive range `0–1`.
  final double l;

  /// Chroma (saturation intensity), typically `0–0.37` for sRGB.
  final double c;

  /// Hue in degrees [0, 360).
  final double h;

  /// Converts a [Color] to an opaque [Oklch].
  ///
  /// sRGB, extended-sRGB, and Display P3 inputs use their native colorimetry.
  /// Floating-point precision is retained, alpha is ignored, and achromatic
  /// hues are represented as zero degrees.
  static Oklch fromColor(Color color) => _OklchConverter.fromColor(color);

  /// Converts OKLCH (L, C, H) to a [Color] in [colorSpace].
  ///
  /// Lightness is clamped to `[0, 1]`, negative chroma becomes zero, and hue
  /// is normalized to `[0, 360)`. Non-finite components throw [ArgumentError].
  /// Colors outside bounded sRGB or Display P3 are perceptually gamut-mapped
  /// using constant lightness and hue with CSS Color 4 OKLCH chroma reduction.
  /// Extended-sRGB output remains unbounded. The default output is sRGB.
  static Color toColor(double l, double c, double h, {ColorSpace colorSpace = ColorSpace.sRGB}) =>
      _OklchConverter.toColor(l, c, h, colorSpace: colorSpace);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Oklch) return false;
    return l == other.l && c == other.c && h == other.h;
  }

  @override
  int get hashCode => Object.hash(l, c, h);

  @override
  String toString() => 'Oklch($l, $c, $h)';
}
