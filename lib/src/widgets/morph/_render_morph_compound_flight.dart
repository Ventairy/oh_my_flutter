part of 'morph.dart';

class _RenderMorphCompoundFlight extends RenderBox {
  _RenderMorphCompoundFlight(
    this._animation,
    this._plan,
    this._sourceBounds,
    this._destinationBounds,
    this._geometry,
    this._devicePixelRatio,
    this._viewId,
    _MorphTextRasterPool? rasterPool,
  ) {
    _plan
      ..viewId = _viewId
      ..rasterPool = rasterPool;
  }

  Animation<double> _animation;
  _MorphCompoundFlightPlan _plan;
  Rect? _sourceBounds;
  Rect? _destinationBounds;
  _MorphFlightGeometry? _geometry;
  double _devicePixelRatio;
  int _viewId;

  @override
  bool get isRepaintBoundary => true;

  @override
  Rect get paintBounds => _paintBounds;

  Animation<double> get animation => _animation;

  _MorphCompoundFlightPlan get plan => _plan;

  Rect? get sourceBounds => _sourceBounds;

  Rect? get destinationBounds => _destinationBounds;

  _MorphFlightGeometry? get geometry => _geometry;

  double get devicePixelRatio => _devicePixelRatio;

  int get viewId => _viewId;

  _MorphTextRasterPool? get rasterPool => _plan.rasterPool;

  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) _animation.removeListener(markNeedsPaint);
    _animation = value;
    if (attached) _animation.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set plan(_MorphCompoundFlightPlan value) {
    if (identical(value, _plan)) return;
    final previousRasterPool = _plan.rasterPool;
    if (attached) _plan.removeListener(markNeedsPaint);
    _plan.dispose();
    _plan = value;
    _plan
      ..viewId = _viewId
      ..rasterPool = previousRasterPool;
    if (attached) _plan.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set sourceBounds(Rect? value) {
    if (value == _sourceBounds) return;
    _sourceBounds = value;
    markNeedsPaint();
  }

  set destinationBounds(Rect? value) {
    if (value == _destinationBounds) return;
    _destinationBounds = value;
    markNeedsPaint();
  }

  set geometry(_MorphFlightGeometry? value) {
    if (identical(value, _geometry)) return;
    if (attached) _geometry?.removeListener(markNeedsPaint);
    _geometry = value;
    if (attached) _geometry?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  set viewId(int value) {
    if (value == _viewId) return;
    _viewId = value;
    _plan.viewId = value;
    markNeedsPaint();
  }

  set rasterPool(_MorphTextRasterPool? value) {
    if (identical(value, _plan.rasterPool)) return;
    _plan.rasterPool = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
    _plan.addListener(markNeedsPaint);
    _geometry?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    _plan.removeListener(markNeedsPaint);
    _geometry?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _plan.dispose();
    super.dispose();
  }

  @override
  void performLayout() {
    size = constraints.biggest.isFinite ? constraints.biggest : constraints.constrain(Size.zero);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final sourceBounds = _geometry?.sourceBounds ?? _sourceBounds;
    final destinationBounds = _geometry?.destinationBounds ?? _destinationBounds;
    final bounds = sourceBounds == null || destinationBounds == null
        ? offset & size
        : Rect.lerp(
            sourceBounds.shift(offset),
            destinationBounds.shift(offset),
            _animation.value,
          )!;
    _plan.paint(
      context.canvas,
      bounds,
      _animation.value,
      devicePixelRatio: _devicePixelRatio,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<List<Map<String, Object?>>>(
          'retainedTextLayouts',
          _plan.debugTextLayouts,
        ),
      )
      ..add(
        IntProperty(
          'retainedDecorationInterpolationsAtProgress',
          _plan.debugDecorationInterpolationsAtProgress,
        ),
      );
    _addPaintBounds(properties);
  }

  void _addPaintBounds(DiagnosticPropertiesBuilder properties) {
    properties.add(DiagnosticsProperty<Rect>('paintBounds', _paintBounds));
  }

  Rect get _paintBounds {
    final sourceBounds = _geometry?.sourceBounds ?? _sourceBounds;
    final destinationBounds = _geometry?.destinationBounds ?? _destinationBounds;
    if (sourceBounds == null || destinationBounds == null) {
      return Offset.zero & size;
    }
    final bounds = Rect.lerp(
      sourceBounds,
      destinationBounds,
      _animation.value,
    )!;
    return _plan
        .paintBounds(bounds, _animation.value)
        .intersect(
          Offset.zero & size,
        );
  }
}
