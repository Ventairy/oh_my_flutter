import 'package:flutter/rendering.dart';

import 'contour_non_rasterizable_test_layer.dart';

/// Paints a visible child whose complete layer cannot be captured.
class ContourNonRasterizableTestRender extends RenderBox {
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(const Size.square(20));

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawRect(offset & size, Paint()..color = const Color(0xFFFF0000));
    context.addLayer(ContourNonRasterizableTestLayer());
  }
}
