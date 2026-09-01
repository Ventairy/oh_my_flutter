part of 'interactive_swipe_dismiss_benchmark.dart';

class _InteractiveSwipeDismissBenchmarkProbeRenderBox extends RenderProxyBox {
  @override
  void performLayout() {
    _InteractiveSwipeDismissBenchmarkProbeCounters.layouts += 1;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _InteractiveSwipeDismissBenchmarkProbeCounters.paints += 1;
    super.paint(context, offset);
  }
}
