import 'dart:ui' show ColorSpace;

import 'package:flutter/material.dart';

import '../oklch/oklch.dart';

/// Utilities for [Oklch] values.
///
/// See the [OKLCH color guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/extensions/oklch.md)
/// for conversion and color-adjustment examples.
extension OklchExtension on Oklch {
  /// Returns this OKLCH color in [colorSpace], which defaults to sRGB.
  Color toColor({ColorSpace colorSpace = ColorSpace.sRGB}) => Oklch.toColor(l, c, h, colorSpace: colorSpace);
}
