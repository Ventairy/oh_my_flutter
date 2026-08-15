part of 'morph.dart';

class _MorphHybridColumnRenderWidget extends MultiChildRenderObjectWidget {
  const _MorphHybridColumnRenderWidget({
    required this.animation,
    required this.plan,
    required this.rasterPool,
    required this.sourceBounds,
    required this.destinationBounds,
    required this.geometry,
    required super.children,
  });

  final Animation<double> animation;
  final _MorphHybridColumnFlightPlan plan;
  final _MorphTextRasterPool? rasterPool;
  final Rect? sourceBounds;
  final Rect? destinationBounds;
  final _MorphFlightGeometry? geometry;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphHybridColumnFlight(
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
    _RenderMorphHybridColumnFlight renderObject,
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
