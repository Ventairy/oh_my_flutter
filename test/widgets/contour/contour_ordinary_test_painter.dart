import 'package:flutter/widgets.dart';

/// Paints the same generic oval without declaring its geometry.
class ContourOrdinaryTestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromLTWH(size.width * .1, size.height * .125, size.width * .8, size.height * .75))
      ..addOval(Rect.fromLTWH(size.width * .49, size.height * .3, size.width * .22, size.height * .28)),
    Paint()..color = const Color(0xFF7948EC),
  );

  @override
  bool shouldRepaint(covariant ContourOrdinaryTestPainter oldDelegate) => false;
}
