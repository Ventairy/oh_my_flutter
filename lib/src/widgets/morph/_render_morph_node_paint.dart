part of 'morph.dart';

class _RenderMorphNodePaint extends RenderBox {
  new({required this._handle});

  _MorphNodeHandle _handle;

  _MorphNodeHandle get handle => _handle;

  set handle(_MorphNodeHandle value) {
    if (identical(value, _handle)) return;
    if (attached) _handle.detachProjection(this);
    _handle = value;
    if (attached) _handle.attachProjection(this);
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _handle.attachProjection(this);
  }

  @override
  void detach() {
    _handle.detachProjection(this);
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  void markSourceNeedsUpdate() => markNeedsPaint();

  @override
  void paint(PaintingContext context, Offset offset) {
    final source = _handle.owner._renderObject;
    if (source != null && source.attached && source.hasSize) {
      context.paintChild(source, Offset.zero);
    }
  }
}
