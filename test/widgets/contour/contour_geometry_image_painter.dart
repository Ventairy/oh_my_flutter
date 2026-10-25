import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Repeats image detail at large logical bounds without creating a large asset.
class ContourGeometryImagePainter extends CustomPainter {
  /// Creates a nearest-sampled source fixture.
  const new(this.image);

  /// The small source image enlarged by the canvas.
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Offset.zero & size,
    Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false,
  );

  @override
  bool shouldRepaint(ContourGeometryImagePainter oldDelegate) => image != oldDelegate.image;
}
