import 'package:flutter/material.dart';

/// Shared helpers for [String] values.
extension StringExtension on String {
  /// Parses this CSS-style hex color string into a [Color].
  ///
  /// Accepts `#RRGGBB`, `#AARRGGBB`, or unprefixed `RRGGBB` formats. If the
  /// hex value is 6 characters (RGB), full opacity (`0xFF`) is assumed. The
  /// `#` prefix is optional.
  ///
  /// Throws a [FormatException] if the string is not a valid hex color.
  ///
  /// ```dart
  /// final color = '#F4F2EF'.hexToColor();
  /// final alpha = '#80FF6347'.hexToColor(); // semi-transparent
  /// final plain = 'F4F2EF'.hexToColor();     // no hash prefix
  /// ```
  Color hexToColor() {
    final cleaned = replaceFirst('#', '');
    final hex = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.parse(hex, radix: 16));
  }
}
