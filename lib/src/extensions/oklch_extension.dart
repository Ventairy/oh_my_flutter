import 'dart:ui' show ColorSpace;

import 'package:flutter/material.dart';

import '../oklch/oklch.dart';

/// Utilities for [Oklch] values.
extension OklchExtension on Oklch {
  /// Returns this OKLCH color in [colorSpace], which defaults to sRGB.
  Color toColor({ColorSpace colorSpace = ColorSpace.sRGB}) =>
      Oklch.toColor(l, c, h, colorSpace: colorSpace);
}
