part of 'morph.dart';

class _MorphDescendantBoundary extends SingleChildRenderObjectWidget {
  const _MorphDescendantBoundary({
    required this.onRenderObjectReady,
    required super.child,
  });

  final void Function(_RenderMorphDescendant renderObject) onRenderObjectReady;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = _RenderMorphDescendant(onRenderObjectReady);
    onRenderObjectReady(renderObject);
    return renderObject;
  }
}
