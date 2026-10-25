import 'package:flutter/widgets.dart';

/// Changes a rectangle's visible width and color without rebuilding widgets.
class ContourRepaintTestPainter extends CustomPainter {
  /// Listens to [changed] for paint-only updates to the source artwork.
  new(this.changed) : super(repaint: changed);

  /// Switches between a blue 40-pixel rectangle and a green 10-pixel rectangle.
  final ValueNotifier<bool> changed;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Rect.fromLTWH(0, 0, changed.value ? 10 : 40, 40),
    Paint()..color = changed.value ? const Color(0xff00ff00) : const Color(0xff0000ff),
  );

  @override
  bool shouldRepaint(ContourRepaintTestPainter oldDelegate) => false;
}
