part of 'morph.dart';

class _MorphHybridContainerRenderWidget extends SingleChildRenderObjectWidget {
  const _MorphHybridContainerRenderWidget({
    required this.animation,
    required this.plan,
    required this.sourceBounds,
    required this.destinationBounds,
    required this.geometry,
    required super.child,
  });

  final Animation<double> animation;
  final _MorphHybridContainerFlightPlan plan;
  final Rect? sourceBounds;
  final Rect? destinationBounds;
  final _MorphFlightGeometry? geometry;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphHybridContainerFlight(
      animation,
      plan,
      sourceBounds,
      destinationBounds,
      geometry,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphHybridContainerFlight renderObject,
  ) {
    renderObject
      ..animation = animation
      ..plan = plan
      ..sourceBounds = sourceBounds
      ..destinationBounds = destinationBounds
      ..geometry = geometry;
  }
}
