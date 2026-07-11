import 'package:flutter/material.dart';

import '../omf_oklch.dart';

/// Extension on [OmfOklch] to convert back to sRGB [Color].
extension OmfOklchExtension on OmfOklch {
  /// Returns the sRGB [Color] representation of this OKLCH color.
  Color toColor() => OmfOklch.toColor(l, c, h);
}
