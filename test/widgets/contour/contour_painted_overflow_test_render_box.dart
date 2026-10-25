import 'package:flutter/rendering.dart';

/// Adds paint beyond the neutral SDK overflow-box contract.
class ContourPaintedOverflowTestRenderBox extends RenderConstrainedOverflowBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawRect(
      offset & size,
      Paint()..color = const Color(0xff00ff00),
    );
    super.paint(context, offset);
  }
}
