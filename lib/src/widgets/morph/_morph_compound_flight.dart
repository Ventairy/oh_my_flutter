part of 'morph.dart';

class _MorphCompoundFlight extends LeafRenderObjectWidget {
  const _MorphCompoundFlight({
    required this.animation,
    required this.plan,
    this.rasterPool,
    this.sourceBounds,
    this.destinationBounds,
    this.geometry,
  });

  final Animation<double> animation;
  final _MorphCompoundFlightPlan plan;
  final _MorphTextRasterPool? rasterPool;
  final Rect? sourceBounds;
  final Rect? destinationBounds;
  final _MorphFlightGeometry? geometry;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphCompoundFlight(
      animation,
      plan,
      sourceBounds,
      destinationBounds,
      geometry,
      View.of(context).devicePixelRatio,
      View.of(context).viewId,
      rasterPool,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphCompoundFlight renderObject,
  ) {
    renderObject
      ..animation = animation
      ..plan = plan
      ..sourceBounds = sourceBounds
      ..destinationBounds = destinationBounds
      ..geometry = geometry
      ..devicePixelRatio = View.of(context).devicePixelRatio
      ..viewId = View.of(context).viewId
      ..rasterPool = rasterPool;
  }
}
