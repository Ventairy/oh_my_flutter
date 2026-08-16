part of 'morph.dart';

class _MorphHybridColumnFlight extends StatelessWidget {
  const _MorphHybridColumnFlight({
    required this.animation,
    required this.plan,
    required this.transitionBuilder,
    this.rasterPool,
    this.sourceBounds,
    this.destinationBounds,
    this.geometry,
  });

  final Animation<double> animation;
  final _MorphHybridColumnFlightPlan plan;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;
  final _MorphTextRasterPool? rasterPool;
  final Rect? sourceBounds;
  final Rect? destinationBounds;
  final _MorphFlightGeometry? geometry;

  @override
  Widget build(BuildContext context) {
    return _MorphHybridColumnRenderWidget(
      animation: animation,
      plan: plan,
      rasterPool: rasterPool,
      sourceBounds: sourceBounds,
      destinationBounds: destinationBounds,
      geometry: geometry,
      children: List<Widget>.generate(
        plan.rawSlotCount,
        (index) => _MorphHybridRawSlot(
          animation: animation,
          plan: plan.rawSlot(index),
          transitionBuilder: transitionBuilder,
          repaintChild: !plan.rawSlot(index).rawSizeChangesContinuously,
        ),
        growable: false,
      ),
    );
  }
}
