import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Holds a validated packed decoration until its image has been decoded.
@internal
final class ContourCompositeOutput {
  /// Retains the one copied native atlas and its bounded placements.
  const new({
    required this.width,
    required this.height,
    required this.rgba,
    required this.placements,
  });

  /// Atlas width in physical output pixels.
  final int width;

  /// Atlas height in physical output pixels.
  final int height;

  /// Premultiplied RGBA pixels in atlas order.
  final Uint8List rgba;

  /// Six coordinates per source: atlas rectangle and local output origin.
  final Float64List placements;
}
