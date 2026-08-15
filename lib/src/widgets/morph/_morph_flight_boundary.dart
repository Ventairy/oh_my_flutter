part of 'morph.dart';

class _MorphFlightBoundary extends SingleChildRenderObjectWidget {
  const _MorphFlightBoundary({required this.paintHandle, required super.child});

  final _MorphFlightPaintHandle paintHandle;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphFlightBoundary(paintHandle);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphFlightBoundary renderObject,
  ) {
    renderObject.paintHandle = paintHandle;
  }
}
