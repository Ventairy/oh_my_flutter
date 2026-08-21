part of 'morph.dart';

class _RenderMorphForegroundPaint extends RenderBox {
  _RenderMorphForegroundPaint({required this._handle});

  static final Matrix4 _hiddenLayerTransform = Matrix4.zero();

  _MorphForegroundHandle _handle;
  bool _canPaintSource = false;
  bool _sourceWasPainted = false;

  _MorphForegroundHandle get handle => _handle;

  set handle(_MorphForegroundHandle value) {
    if (identical(value, _handle)) return;
    if (attached) _handle.detachProjection(this);
    _handle = value;
    if (attached) _handle.attachProjection(this);
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

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
    _sourceWasPainted = false;
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  void markTransformNeedsUpdate() {
    if (_sourceWasPainted) {
      markNeedsCompositedLayerUpdate();
      return;
    }
    markNeedsPaint();
  }

  void markSourceNeedsUpdate() {
    _sourceWasPainted = false;
    markNeedsPaint();
  }

  @override
  TransformLayer updateCompositedLayer({
    required covariant TransformLayer? oldLayer,
  }) {
    final transform = _handle.resolveTransform();
    _canPaintSource = transform != null;
    if (transform == null) _sourceWasPainted = false;
    final layer = oldLayer ?? TransformLayer();
    final previousTransform = layer.transform;
    if (previousTransform != null && previousTransform == (transform ?? _hiddenLayerTransform)) {
      return layer;
    }
    if (transform == null) {
      layer.transform = _hiddenLayerTransform;
      return layer;
    }
    layer.transform = _handle.copyLayerTransform(transform);
    return layer;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_canPaintSource) {
      _sourceWasPainted = false;
      return;
    }
    final source = _handle.owner._renderObject;
    if (source != null && source.attached && source.hasSize) {
      context.paintChild(source, Offset.zero);
      _sourceWasPainted = true;
      return;
    }
    _sourceWasPainted = false;
  }
}
