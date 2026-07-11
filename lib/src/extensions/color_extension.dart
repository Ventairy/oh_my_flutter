import 'package:flutter/material.dart';

import '../omf_oklch.dart';

/// Shared helpers for Flutter [Color] values.
extension ColorExtension on Color {
  /// Returns this color lightened toward white by [amount].
  ///
  /// [amount] is clamped between `0` and `1`.
  Color lighten(double amount) {
    return Color.lerp(this, Colors.white, amount.clamp(0, 1))!;
  }

  /// Returns this color darkened toward black by [amount].
  ///
  /// [amount] is clamped between `0` and `1`.
  Color darken(double amount) {
    return Color.lerp(this, Colors.black, amount.clamp(0, 1))!;
  }

  /// Returns the `#RRGGBB` hex string of this color.
  ///
  /// Alpha is ignored — only the RGB channels are included.
  String toHex() {
    return '#${(r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(b * 255).round().toRadixString(16).padLeft(2, '0')}';
  }

  /// Converts this sRGB [Color] to an [OmfOklch] representation.
  OmfOklch toOklch() => OmfOklch.fromColor(this);
}
