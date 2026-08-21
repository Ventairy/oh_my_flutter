part of 'morph.dart';

class _MorphForegroundBoundary extends SingleChildRenderObjectWidget {
  const _MorphForegroundBoundary({
    required this.handle,
    required this.onRenderObjectReady,
    required this.onGeometryChanged,
    required super.child,
  });

  final _MorphForegroundHandle? handle;
  final ValueChanged<_RenderMorphForegroundBoundary> onRenderObjectReady;
  final VoidCallback onGeometryChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = _RenderMorphForegroundBoundary(
      handle,
      onGeometryChanged: onGeometryChanged,
    );
    onRenderObjectReady(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphForegroundBoundary renderObject,
  ) {
    renderObject
      ..handle = handle
      ..onGeometryChanged = onGeometryChanged;
    onRenderObjectReady(renderObject);
  }
}
