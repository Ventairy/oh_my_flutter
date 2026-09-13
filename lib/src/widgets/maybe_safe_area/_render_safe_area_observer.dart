part of 'maybe_safe_area.dart';

class _RenderSafeAreaObserver extends RenderProxyBox {
  _RenderSafeAreaObserver({
    required this._handle,
    required this._padding,
    required this._viewSize,
    required this._edges,
  });

  SafeAreaObserverHandle _handle;
  EdgeInsets _padding;
  Size _viewSize;
  _MaybeSafeAreaEdges _edges;
  final _SafeAreaTransform _viewTransform = _SafeAreaTransform();

  SafeAreaObserverHandle get handle => _handle;
  set handle(SafeAreaObserverHandle value) {
    if (identical(value, _handle)) return;
    if (attached) _handle._detach(this);
    _handle = value;
    if (attached) _handle._attach(this);
    markNeedsPaint();
  }

  void configure({required EdgeInsets padding, required Size viewSize, required _MaybeSafeAreaEdges edges}) {
    if (_padding == padding && _viewSize == viewSize && _edges == edges) return;
    _padding = padding;
    _viewSize = viewSize;
    _edges = edges;
    markNeedsPaint();
  }

  EdgeInsets? get currentInsets {
    if (!attached || !hasSize) return null;
    final transform = _viewTransform.resolve(this);
    return transform == null ? null : _insetsFor(transform);
  }

  EdgeInsets? _insetsFor(Matrix4 transform) {
    final bounds = MatrixUtils.transformRect(transform, Offset.zero & size);
    if (!bounds.isFinite || bounds.width <= 0 || bounds.height <= 0) return null;
    if (!bounds.overlaps(Offset.zero & _viewSize)) return EdgeInsets.zero;
    // Measure only overlap with the unsafe band, never offscreen distance.
    final scaleX = size.width / bounds.width;
    final scaleY = size.height / bounds.height;
    double overlap(double start, double end, double unsafeStart, double unsafeEnd) =>
        end.clamp(unsafeStart, unsafeEnd) - start.clamp(unsafeStart, unsafeEnd);
    return EdgeInsets.fromLTRB(
      _edges.left ? overlap(bounds.left, bounds.right, 0, _padding.left) * scaleX : 0,
      _edges.top ? overlap(bounds.top, bounds.bottom, 0, _padding.top) * scaleY : 0,
      _edges.right ? overlap(bounds.left, bounds.right, _viewSize.width - _padding.right, _viewSize.width) * scaleX : 0,
      _edges.bottom
          ? overlap(bounds.top, bounds.bottom, _viewSize.height - _padding.bottom, _viewSize.height) * scaleY
          : 0,
    );
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _handle._attach(this);
  }

  @override
  void detach() {
    _viewTransform.reset();
    _handle._detach(this);
    layer = null;
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _handle._publish(currentInsets);
    final observerLayer =
        (layer ??= _SafeAreaObserverLayer(() {
              if (attached) _handle._publish(currentInsets);
            }))
            as _SafeAreaObserverLayer;
    context.pushLayer(observerLayer, super.paint, offset);
  }
}
