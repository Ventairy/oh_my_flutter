part of 'morph.dart';

class _MorphNodePaint extends LeafRenderObjectWidget {
  const new({required this.handle});

  final _MorphNodeHandle handle;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphNodePaint(handle: handle);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphNodePaint renderObject,
  ) {
    renderObject.handle = handle;
  }
}
