part of 'morph.dart';

class _RenderMorphSiblingBoundary extends RenderProxyBox {
  _RenderMorphSiblingBoundary(
    this._handle, {
    required this.onGeometryChanged,
  });

  _MorphSiblingHandle? _handle;
  VoidCallback onGeometryChanged;
  bool _projected = false;

  _MorphSiblingHandle? get handle => _handle;

  set handle(_MorphSiblingHandle? value) {
    if (identical(value, _handle)) return;
    _handle = value;
  }

  @override
  bool get isRepaintBoundary => _projected;

  bool get projected => _projected;

  set projected(bool value) {
    if (value == _projected) return;
    _projected = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  void performLayout() {
    final previousSize = hasSize ? size : null;
    super.performLayout();
    if (size != previousSize) onGeometryChanged();
  }

  @override
  void dispose() {
    _handle?.renderObjectDisposed(this);
    super.dispose();
  }
}
