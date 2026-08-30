part of 'morph.dart';

class _MorphSiblingBoundary extends SingleChildRenderObjectWidget {
  const _MorphSiblingBoundary({
    required this.handle,
    required this.onRenderObjectReady,
    required this.onGeometryChanged,
    required super.child,
  });

  final _MorphSiblingHandle? handle;
  final ValueChanged<_RenderMorphSiblingBoundary> onRenderObjectReady;
  final VoidCallback onGeometryChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = _RenderMorphSiblingBoundary(
      handle,
      onGeometryChanged: onGeometryChanged,
    );
    onRenderObjectReady(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphSiblingBoundary renderObject,
  ) {
    renderObject
      ..handle = handle
      ..onGeometryChanged = onGeometryChanged;
    onRenderObjectReady(renderObject);
  }
}
