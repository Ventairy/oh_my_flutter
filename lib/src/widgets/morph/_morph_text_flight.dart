part of 'morph.dart';

class _MorphTextFlight extends LeafRenderObjectWidget {
  const _MorphTextFlight({
    required this.delegate,
    required this.flight,
    this.rasterPool,
    this.geometry,
  });

  final MorphTextFlightDelegate delegate;
  final MorphFlight<MorphTextProperties> flight;
  final _MorphTextRasterPool? rasterPool;
  final _MorphFlightGeometry? geometry;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphTextFlight(
      delegate,
      flight,
      View.of(context).devicePixelRatio,
      View.of(context).viewId,
      rasterPool,
      geometry,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphTextFlight renderObject,
  ) {
    renderObject
      ..delegate = delegate
      ..flight = flight
      ..devicePixelRatio = View.of(context).devicePixelRatio
      ..viewId = View.of(context).viewId
      ..rasterPool = rasterPool
      ..geometry = geometry;
  }
}
