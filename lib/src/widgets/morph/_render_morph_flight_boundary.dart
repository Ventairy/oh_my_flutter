part of 'morph.dart';

class _RenderMorphFlightBoundary extends RenderProxyBox {
  _RenderMorphFlightBoundary(
    this._paintHandle,
    this._ancestorAnimation,
    this._ancestorGeometry,
    this._ancestorSourceBounds,
    this._ancestorDestinationBounds,
  );

  _MorphFlightPaintHandle _paintHandle;
  Animation<double>? _ancestorAnimation;
  _MorphFlightGeometry? _ancestorGeometry;
  Rect? _ancestorSourceBounds;
  Rect? _ancestorDestinationBounds;
  final LayerHandle<ClipRectLayer> _clipRectLayer = LayerHandle<ClipRectLayer>();
  final LayerHandle<OpacityLayer> _handoffOpacityLayer = LayerHandle<OpacityLayer>();

  _MorphFlightPaintHandle get paintHandle => _paintHandle;

  Animation<double>? get ancestorAnimation => _ancestorAnimation;

  _MorphFlightGeometry? get ancestorGeometry => _ancestorGeometry;

  Rect? get ancestorSourceBounds => _ancestorSourceBounds;

  Rect? get ancestorDestinationBounds => _ancestorDestinationBounds;

  @override
  Rect get paintBounds {
    if (!_paintHandle.visible && !_paintHandle.handoffPrepared) {
      return Rect.zero;
    }
    final clipBounds = _ancestorClipBounds;
    return clipBounds == null ? super.paintBounds : super.paintBounds.intersect(clipBounds);
  }

  set paintHandle(_MorphFlightPaintHandle value) {
    if (identical(value, _paintHandle)) return;
    if (attached) _paintHandle.removeListener(_handlePaintHandleChanged);
    _paintHandle = value;
    if (attached) _paintHandle.addListener(_handlePaintHandleChanged);
    _handlePaintHandleChanged();
  }

  set ancestorAnimation(Animation<double>? value) {
    if (identical(value, _ancestorAnimation)) return;
    if (attached) _ancestorAnimation?.removeListener(markNeedsPaint);
    _ancestorAnimation = value;
    if (attached) _ancestorAnimation?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set ancestorGeometry(_MorphFlightGeometry? value) {
    if (identical(value, _ancestorGeometry)) return;
    if (attached) _ancestorGeometry?.removeListener(markNeedsPaint);
    _ancestorGeometry = value;
    if (attached) _ancestorGeometry?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set ancestorSourceBounds(Rect? value) {
    if (value == _ancestorSourceBounds) return;
    _ancestorSourceBounds = value;
    markNeedsPaint();
  }

  set ancestorDestinationBounds(Rect? value) {
    if (value == _ancestorDestinationBounds) return;
    _ancestorDestinationBounds = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _paintHandle.addListener(_handlePaintHandleChanged);
    _ancestorAnimation?.addListener(markNeedsPaint);
    _ancestorGeometry?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _paintHandle.removeListener(_handlePaintHandleChanged);
    _ancestorAnimation?.removeListener(markNeedsPaint);
    _ancestorGeometry?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_paintHandle.handoffPrepared) {
      _handoffOpacityLayer.layer = context.pushOpacity(
        offset,
        _paintHandle.visible ? 255 : 0,
        _paintFlight,
        oldLayer: _handoffOpacityLayer.layer,
      );
      return;
    }
    _handoffOpacityLayer.layer = null;
    if (!_paintHandle.visible) {
      _clipRectLayer.layer = null;
      return;
    }
    _paintFlight(context, offset);
  }

  void _paintFlight(PaintingContext context, Offset offset) {
    final clipBounds = _ancestorClipBounds;
    if (clipBounds == null) {
      _clipRectLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _clipRectLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      clipBounds,
      super.paint,
      clipBehavior: Clip.hardEdge,
      oldLayer: _clipRectLayer.layer,
    );
  }

  @override
  void dispose() {
    _clipRectLayer.layer = null;
    _handoffOpacityLayer.layer = null;
    super.dispose();
  }

  void _handlePaintHandleChanged() {
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  Rect? get _ancestorClipBounds {
    final animation = _ancestorAnimation;
    final source = _ancestorGeometry?.sourceBounds ?? _ancestorSourceBounds;
    final destination = _ancestorGeometry?.destinationBounds ?? _ancestorDestinationBounds;
    if (animation == null || source == null || destination == null) return null;
    return Rect.lerp(source, destination, animation.value);
  }
}
