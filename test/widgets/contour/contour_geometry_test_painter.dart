import 'package:flutter/rendering.dart';

/// Paints many independent opaque details without allocating a large image.
class ContourGeometryTestPainter extends CustomPainter {
  /// Creates a repeated square pattern in logical coordinates.
  const new({this.cellSize = 1});

  /// The width and height of each transparent or painted square.
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF0000)
      ..isAntiAlias = false;
    for (var y = 0; y < (size.height / cellSize).ceil(); y++) {
      for (var x = y % 2; x < (size.width / cellSize).ceil(); x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(ContourGeometryTestPainter oldDelegate) => cellSize != oldDelegate.cellSize;
}
