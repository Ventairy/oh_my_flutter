import 'package:flutter/widgets.dart';

/// Keeps delayed-preparation tests on the asynchronous sampled-source path.
class ContourEntranceTestPainter extends CustomPainter {
  /// Creates a solid source without declaring an immediate contour path.
  const new();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF0000));

  @override
  bool shouldRepaint(ContourEntranceTestPainter oldDelegate) => false;
}
