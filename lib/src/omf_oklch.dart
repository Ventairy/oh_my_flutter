import 'dart:math' as math;

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
final class OmfOklch {
  /// Creates an OKLCH color.
  const OmfOklch(this.l, this.c, this.h);

  /// Lightness in [0, 1].
  final double l;

  /// Chroma (saturation intensity) in [0, ~0.37] for sRGB.
  final double c;

  /// Hue in degrees [0, 360).
  final double h;

  /// Converts an sRGB [Color] to an [OmfOklch].
  static OmfOklch fromColor(Color color) => _OklchConverter.fromColor(color);

  /// Converts OKLCH (L, C, H) to an sRGB [Color].
  ///
  /// Applies gamut clipping via chroma reduction if the color falls outside
  /// the sRGB gamut.
  static Color toColor(double l, double c, double h) => _OklchConverter.toColor(l, c, h);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OmfOklch) return false;
    return l == other.l && c == other.c && h == other.h;
  }

  @override
  int get hashCode => Object.hash(l, c, h);

  @override
  String toString() => 'OmfOklch($l, $c, $h)';
}
