part of 'morph.dart';

class _RenderMorphHybridColumnFlight extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>,
        RenderBoxContainerDefaultsMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  _RenderMorphHybridColumnFlight(
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
  _MorphHybridColumnFlightPlan _plan;
  Rect? _sourceBounds;
  Rect? _destinationBounds;
  _MorphFlightGeometry? _geometry;
  double _devicePixelRatio;
  int _viewId;
  final List<RenderBox> _rawChildren = <RenderBox>[];
  double? _cachedFlightBoundsProgress;
  Rect? _cachedFlightBoundsSource;
  Rect? _cachedFlightBoundsDestination;
  late Rect _cachedFlightBounds;
  int _debugLayoutCount = 0;
  late double _lastProgress = _animation.value;

  @override
  bool get isRepaintBoundary => true;

  @override
  Rect get paintBounds {
    return _plan.paintBounds(_flightBounds, _animation.value).intersect(Offset.zero & size);
  }

  Animation<double> get animation => _animation;

  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) _animation.removeListener(_handleFlightChanged);
    _animation = value;
    _lastProgress = value.value;
    if (attached) _animation.addListener(_handleFlightChanged);
    markNeedsLayout();
  }

  _MorphHybridColumnFlightPlan get plan => _plan;

  set plan(_MorphHybridColumnFlightPlan value) {
    if (identical(value, _plan)) return;
    final previousRasterPool = _plan.rasterPool;
    if (attached) _plan.removeListener(markNeedsPaint);
    _plan.dispose();
    _plan = value;
    _plan
      ..viewId = _viewId
      ..rasterPool = previousRasterPool;
    if (attached) _plan.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  Rect? get sourceBounds => _sourceBounds;

  set sourceBounds(Rect? value) {
    if (value == _sourceBounds) return;
    _sourceBounds = value;
    markNeedsLayout();
  }

  Rect? get destinationBounds => _destinationBounds;

  set destinationBounds(Rect? value) {
    if (value == _destinationBounds) return;
    _destinationBounds = value;
    markNeedsLayout();
  }

  _MorphFlightGeometry? get geometry => _geometry;

  set geometry(_MorphFlightGeometry? value) {
    if (identical(value, _geometry)) return;
    if (attached) _geometry?.removeListener(_handleFlightChanged);
    _geometry = value;
    if (attached) _geometry?.addListener(_handleFlightChanged);
    _handleFlightChanged();
  }

  double get devicePixelRatio => _devicePixelRatio;

  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  int get viewId => _viewId;

  set viewId(int value) {
    if (value == _viewId) return;
    _viewId = value;
    _plan.viewId = value;
    markNeedsPaint();
  }

  _MorphTextRasterPool? get rasterPool => _plan.rasterPool;

  set rasterPool(_MorphTextRasterPool? value) {
    if (identical(value, _plan.rasterPool)) return;
    _plan.rasterPool = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphHybridColumnParentData) {
      child.parentData = _MorphHybridColumnParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_handleFlightChanged);
    _plan.addListener(markNeedsPaint);
    _geometry?.addListener(_handleFlightChanged);
  }

  @override
  void detach() {
    _animation.removeListener(_handleFlightChanged);
    _plan.removeListener(markNeedsPaint);
    _geometry?.removeListener(_handleFlightChanged);
    super.detach();
  }

  @override
  void dispose() {
    _plan.dispose();
    super.dispose();
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.biggest.isFinite ? constraints.biggest : constraints.constrain(Size.zero);
  }

  @override
  void performLayout() {
    assert(() {
      _debugLayoutCount += 1;
      return true;
    }(), 'Hybrid Column layout should be observable in debug mode.');
    size = computeDryLayout(constraints);
    _refreshRawChildren();
    _plan.layoutRawChildren(
      _rawChildren,
      _flightBounds,
      _animation.value,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _plan.paint(
      context,
      offset,
      _flightBounds,
      _animation.value,
      _rawChildren,
      devicePixelRatio: _devicePixelRatio,
    );
  }

  @override
  bool hitTestChildren(
    BoxHitTestResult result, {
    required Offset position,
  }) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final parentData = child.parentData! as ContainerBoxParentData<RenderBox>;
    transform.translateByDouble(
      parentData.offset.dx,
      parentData.offset.dy,
      0,
      1,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('layoutCount', _debugLayoutCount))
      ..add(IntProperty('rawSlotCount', _rawChildren.length))
      ..add(
        DiagnosticsProperty<List<Map<String, Object?>>>(
          'retainedTextLayouts',
          _plan.debugTextLayouts,
        ),
      )
      ..add(DiagnosticsProperty<Rect>('flightBounds', _flightBounds))
      ..add(DiagnosticsProperty<Rect>('paintBounds', paintBounds));
  }

  Rect get _flightBounds {
    final source = _geometry?.sourceBounds ?? _sourceBounds;
    final destination = _geometry?.destinationBounds ?? _destinationBounds;
    if (source == null || destination == null) return Offset.zero & size;
    final progress = _animation.value;
    if (_cachedFlightBoundsProgress == progress &&
        _cachedFlightBoundsSource == source &&
        _cachedFlightBoundsDestination == destination) {
      return _cachedFlightBounds;
    }
    final result = Rect.fromLTWH(
      source.left == destination.left ? source.left : ui.lerpDouble(source.left, destination.left, progress)!,
      source.top == destination.top ? source.top : ui.lerpDouble(source.top, destination.top, progress)!,
      source.width == destination.width
          ? source.width
          : math.max(
              0,
              ui.lerpDouble(source.width, destination.width, progress)!,
            ),
      source.height == destination.height
          ? source.height
          : math.max(
              0,
              ui.lerpDouble(source.height, destination.height, progress)!,
            ),
    );
    _cachedFlightBoundsProgress = progress;
    _cachedFlightBoundsSource = source;
    _cachedFlightBoundsDestination = destination;
    _cachedFlightBounds = result;
    return result;
  }

  void _refreshRawChildren() {
    _rawChildren.clear();
    var child = firstChild;
    while (child != null) {
      _rawChildren.add(child);
      final parentData = child.parentData! as ContainerBoxParentData<RenderBox>;
      child = parentData.nextSibling;
    }
  }

  void _handleFlightChanged() {
    final progress = _animation.value;
    final rawSelectionChanged = _plan.rawSelectionChangesBetween(
      _lastProgress,
      progress,
    );
    _lastProgress = progress;
    if (_plan.requiresFrameLayout || rawSelectionChanged) {
      markNeedsLayout();
      return;
    }
    markNeedsPaint();
  }
}
