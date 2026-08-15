part of 'morph.dart';

class _MorphEndpointBoundary extends SingleChildRenderObjectWidget {
  const _MorphEndpointBoundary({
    required this.visibility,
    required this.onRenderObjectReady,
    required this.onPaint,
    required super.child,
  });

  final _MorphVisibilityHandle visibility;
  final ValueChanged<_RenderMorphEndpoint> onRenderObjectReady;
  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = _RenderMorphEndpoint(visibility, onPaint);
    onRenderObjectReady(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphEndpoint renderObject,
  ) {
    renderObject
      ..visibility = visibility
      ..onPaint = onPaint;
    onRenderObjectReady(renderObject);
  }
}
