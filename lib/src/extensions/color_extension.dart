import 'package:flutter/material.dart';

import '../oklch/oklch.dart';

/// Utilities for Flutter [Color] values.
extension ColorExtension on Color {
  /// Returns this color lightened toward white by [amount].
  ///
  /// [amount] is clamped between `0` and `1`. A value of `0` leaves the color
  /// unchanged and a value of `1` returns white.
  Color lighten(double amount) {
    return Color.lerp(this, Colors.white, amount.clamp(0, 1))!;
  }

  /// Returns this color darkened toward black by [amount].
  ///
  /// [amount] is clamped between `0` and `1`. A value of `0` leaves the color
  /// unchanged and a value of `1` returns black.
  Color darken(double amount) {
    return Color.lerp(this, Colors.black, amount.clamp(0, 1))!;
  }

  /// Returns the `#RRGGBB` hex string of this color.
  ///
  /// Alpha is ignored and the hexadecimal digits are lowercase.
  String toHex() {
    return '#${(r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(b * 255).round().toRadixString(16).padLeft(2, '0')}';
  }

  /// Converts this color to an opaque [Oklch] using its native color space.
  ///
  /// Alpha is intentionally ignored by the [Oklch] value model.
  Oklch toOklch() => Oklch.fromColor(this);
}
