part of 'morph.dart';

class _MorphPositionedFlight extends SingleChildRenderObjectWidget {
  const _MorphPositionedFlight({
    required this.animation,
    required this.geometry,
    required this.sourceBounds,
    required this.destinationBounds,
    required super.child,
  });

  final Animation<double> animation;
  final _MorphFlightGeometry? geometry;
  final Rect sourceBounds;
  final Rect destinationBounds;

  @override
  _RenderMorphPositionedFlight createRenderObject(BuildContext context) {
    return _RenderMorphPositionedFlight(
      animation,
      geometry,
      sourceBounds,
      destinationBounds,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphPositionedFlight renderObject,
  ) {
    renderObject
      ..animation = animation
      ..geometry = geometry
      ..sourceBounds = sourceBounds
      ..destinationBounds = destinationBounds;
  }
}
