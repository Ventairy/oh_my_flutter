part of 'morph.dart';

class _MorphFlightBoundary extends SingleChildRenderObjectWidget {
  const _MorphFlightBoundary({
    required this.paintHandle,
    required super.child,
    this.ancestorAnimation,
    this.ancestorGeometry,
    this.ancestorSourceBounds,
    this.ancestorDestinationBounds,
  });

  final _MorphFlightPaintHandle paintHandle;
  final Animation<double>? ancestorAnimation;
  final _MorphFlightGeometry? ancestorGeometry;
  final Rect? ancestorSourceBounds;
  final Rect? ancestorDestinationBounds;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphFlightBoundary(
      paintHandle,
      ancestorAnimation,
      ancestorGeometry,
      ancestorSourceBounds,
      ancestorDestinationBounds,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphFlightBoundary renderObject,
  ) {
    renderObject
      ..paintHandle = paintHandle
      ..ancestorAnimation = ancestorAnimation
      ..ancestorGeometry = ancestorGeometry
      ..ancestorSourceBounds = ancestorSourceBounds
      ..ancestorDestinationBounds = ancestorDestinationBounds;
  }
}
