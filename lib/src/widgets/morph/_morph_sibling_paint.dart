part of 'morph.dart';

class _MorphSiblingPaint extends LeafRenderObjectWidget {
  const _MorphSiblingPaint({required this.handle});

  final _MorphSiblingHandle handle;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphSiblingPaint(handle: handle);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphSiblingPaint renderObject,
  ) {
    renderObject.handle = handle;
  }
}
