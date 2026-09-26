part of 'morph.dart';

class _MorphNodeBoundary extends SingleChildRenderObjectWidget {
  const new({
    required this.handle,
    required this.onRenderObjectReady,
    required this.onGeometryChanged,
    required super.child,
  });

  final _MorphNodeHandle? handle;
  final ValueChanged<_RenderMorphNodeBoundary> onRenderObjectReady;
  final VoidCallback onGeometryChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = _RenderMorphNodeBoundary(
      handle,
      onGeometryChanged: onGeometryChanged,
    );
    onRenderObjectReady(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphNodeBoundary renderObject,
  ) {
    renderObject
      ..handle = handle
      ..onGeometryChanged = onGeometryChanged;
    onRenderObjectReady(renderObject);
  }
}
