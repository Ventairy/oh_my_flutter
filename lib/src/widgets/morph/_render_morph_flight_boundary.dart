part of 'morph.dart';

class _RenderMorphFlightBoundary extends RenderProxyBox {
  _RenderMorphFlightBoundary(this._paintHandle);

  _MorphFlightPaintHandle _paintHandle;

  _MorphFlightPaintHandle get paintHandle => _paintHandle;

  @override
  Rect get paintBounds => _paintHandle.visible ? super.paintBounds : Rect.zero;

  set paintHandle(_MorphFlightPaintHandle value) {
    if (identical(value, _paintHandle)) return;
    if (attached) _paintHandle.removeListener(markNeedsPaint);
    _paintHandle = value;
    if (attached) _paintHandle.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _paintHandle.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _paintHandle.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_paintHandle.visible) return;
    super.paint(context, offset);
  }
}
