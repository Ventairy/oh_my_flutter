import 'package:flutter/widgets.dart';

/// Draws a solid source that exercises sampled capture instead of box admission.
class ContourSolidTestPainter extends CustomPainter {
  /// Creates a source whose visible color can change between captures.
  const new({this.color = const Color(0xFFFF0000)});

  /// The source's visible color.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(Offset.zero & size, Paint()..color = color);

  @override
  bool shouldRepaint(ContourSolidTestPainter oldDelegate) => color != oldDelegate.color;
}
