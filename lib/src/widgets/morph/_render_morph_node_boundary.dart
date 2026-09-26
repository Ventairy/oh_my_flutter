part of 'morph.dart';

class _RenderMorphNodeBoundary extends RenderProxyBox {
  new(
    this._handle, {
    required this.onGeometryChanged,
  });

  _MorphNodeHandle? _handle;
  VoidCallback onGeometryChanged;
  bool _projected = false;

  _MorphNodeHandle? get handle => _handle;

  set handle(_MorphNodeHandle? value) {
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
