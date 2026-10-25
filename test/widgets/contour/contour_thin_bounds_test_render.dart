import 'package:flutter/rendering.dart';

/// Exercises a finite capture whose rounded pixel width exceeds admission.
class ContourThinBoundsTestRender extends RenderBox {
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(const Size.square(20));

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  Rect get paintBounds => const Rect.fromLTWH(0, 0, 1000000000000, 20);

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawRect(offset & size, Paint()..color = const Color(0xFFFF0000));
  }
}
