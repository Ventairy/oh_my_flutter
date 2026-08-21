import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

/// Repaints a lightweight caret without rebuilding its foreground control.
final class MorphBenchmarkLiveCaretPainter extends CustomPainter {
  /// Creates a caret driven directly by [animation] paint notifications.
  MorphBenchmarkLiveCaretPainter(this.animation)
    : _paint = Paint()..color = const Color(0xFF2563EB),
      super(repaint: animation);

  static const _caret = Rect.fromLTWH(0, 0, 2, 22);

  /// Animation that moves the caret while the benchmark is active.
  final Animation<double> animation;

  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(
        size.width * 0.58 + animation.value * 3,
        (size.height - _caret.height) / 2,
      )
      ..drawRect(_caret, _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(MorphBenchmarkLiveCaretPainter oldDelegate) {
    return !identical(animation, oldDelegate.animation);
  }
}
