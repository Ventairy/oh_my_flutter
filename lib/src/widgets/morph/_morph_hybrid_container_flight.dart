part of 'morph.dart';

class _MorphHybridContainerFlight extends StatelessWidget {
  const _MorphHybridContainerFlight({
    required this.animation,
    required this.plan,
    required this.transitionBuilder,
    this.sourceBounds,
    this.destinationBounds,
    this.geometry,
  });

  final Animation<double> animation;
  final _MorphHybridContainerFlightPlan plan;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;
  final Rect? sourceBounds;
  final Rect? destinationBounds;
  final _MorphFlightGeometry? geometry;

  @override
  Widget build(BuildContext context) {
    return _MorphFlightScope(
      descendantResolver: null,
      child: _MorphHybridContainerRenderWidget(
        animation: animation,
        plan: plan,
        sourceBounds: sourceBounds,
        destinationBounds: destinationBounds,
        geometry: geometry,
        child: _MorphHybridRawSlot(
          animation: animation,
          plan: plan,
          transitionBuilder: transitionBuilder,
          clipToSlot: true,
          alignToTopLeft: false,
          repaintChild: !plan.requiresFrameLayout,
        ),
      ),
    );
  }
}
