import 'package:flutter/widgets.dart';

class ContourCompositeTestPainter extends CustomPainter {
  new(this.onPaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1278AB));
  }

  @override
  bool shouldRepaint(ContourCompositeTestPainter oldDelegate) => false;
}
