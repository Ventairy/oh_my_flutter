import 'dart:ui';

/// Configures benchmark paint with an explicit eight-digit ARGB value.
abstract final class ContourBenchmarkColor {
  /// Parses [hex] as alpha, red, green, and blue without a prefix.
  ///
  /// Throws [FormatException] when the runtime configuration is malformed.
  static Color parse(String hex) {
    if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(hex)) {
      throw const FormatException('contourColor must contain exactly eight hexadecimal ARGB digits.');
    }
    return Color(int.parse(hex, radix: 16));
  }
}
