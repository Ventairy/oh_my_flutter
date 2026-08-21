part of 'morph.dart';

class _MorphForegroundPaint extends LeafRenderObjectWidget {
  const _MorphForegroundPaint({required this.handle});

  final _MorphForegroundHandle handle;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMorphForegroundPaint(handle: handle);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphForegroundPaint renderObject,
  ) {
    renderObject.handle = handle;
  }
}
