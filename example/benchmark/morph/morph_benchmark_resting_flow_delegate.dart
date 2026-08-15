import 'package:flutter/material.dart';

/// Paint-only translation used by the resting-endpoint Morph benchmark.
final class MorphBenchmarkRestingFlowDelegate extends FlowDelegate {
  /// Creates a flow delegate driven by the benchmark's measurement clock.
  MorphBenchmarkRestingFlowDelegate(this.animation) : super(repaint: animation);

  /// Progress shared with the measurement window.
  final Animation<double> animation;

  final Matrix4 _transform = Matrix4.identity();

  @override
  void paintChildren(FlowPaintingContext context) {
    _transform.setTranslationRaw(0, 40 - 80 * animation.value, 0);
    context.paintChild(0, transform: _transform);
  }

  @override
  bool shouldRepaint(
    covariant MorphBenchmarkRestingFlowDelegate oldDelegate,
  ) {
    return !identical(animation, oldDelegate.animation);
  }
}
