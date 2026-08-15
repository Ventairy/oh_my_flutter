part of 'morph.dart';

class _RenderMorphHybridContainerFlight extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  _RenderMorphHybridContainerFlight(
    this._animation,
    this._plan,
    this._sourceBounds,
    this._destinationBounds,
    this._geometry,
  );

  Animation<double> _animation;
  _MorphHybridContainerFlightPlan _plan;
  Rect? _sourceBounds;
  Rect? _destinationBounds;
  _MorphFlightGeometry? _geometry;
  Offset _childOffset = Offset.zero;
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
    final progress = _animation.value;
    final bounds = _flightBounds;
    var result = _plan.decorationPaintBounds(bounds, progress);
    final rawChild = child;
    if (rawChild != null && _plan.rawPropertiesAt(progress) != null && _updateChildOffset(progress, bounds)) {
      result = result.expandToInclude(
        rawChild.paintBounds.shift(_childOffset),
      );
    }
    return result.intersect(Offset.zero & size);
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

  _MorphHybridContainerFlightPlan get plan => _plan;

  set plan(_MorphHybridContainerFlightPlan value) {
    if (identical(value, _plan)) return;
    _plan.dispose();
    _plan = value;
    markNeedsLayout();
  }

  Rect? get sourceBounds => _sourceBounds;

  set sourceBounds(Rect? value) {
    if (value == _sourceBounds) return;
    _sourceBounds = value;
    markNeedsPaint();
  }

  Rect? get destinationBounds => _destinationBounds;

  set destinationBounds(Rect? value) {
    if (value == _destinationBounds) return;
    _destinationBounds = value;
    markNeedsPaint();
  }

  _MorphFlightGeometry? get geometry => _geometry;

  set geometry(_MorphFlightGeometry? value) {
    if (identical(value, _geometry)) return;
    if (attached) _geometry?.removeListener(_handleFlightChanged);
    _geometry = value;
    if (attached) _geometry?.addListener(_handleFlightChanged);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_handleFlightChanged);
    _geometry?.addListener(_handleFlightChanged);
  }

  @override
  void detach() {
    _animation.removeListener(_handleFlightChanged);
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
    }(), 'Hybrid Container layout should be observable in debug mode.');
    size = computeDryLayout(constraints);
    child?.layout(
      BoxConstraints.tight(
        _plan.rawLayoutSizeAt(_animation.value),
      ),
      parentUsesSize: false,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final progress = _animation.value;
    final bounds = _flightBounds;
    final shiftedBounds = bounds.shift(offset);
    _plan.paintBackground(context.canvas, shiftedBounds, progress);

    final rawChild = child;
    if (rawChild != null && _plan.rawPropertiesAt(progress) != null && _updateChildOffset(progress, bounds)) {
      context.paintChild(rawChild, offset + _childOffset);
    }

    _plan.paintForeground(context.canvas, shiftedBounds, progress);
  }

  @override
  bool hitTestChildren(
    BoxHitTestResult result, {
    required Offset position,
  }) {
    final rawChild = child;
    final progress = _animation.value;
    if (rawChild == null || !_updateChildOffset(progress, _flightBounds)) {
      return false;
    }
    return result.addWithPaintOffset(
      offset: _childOffset,
      position: position,
      hitTest: (result, position) {
        return rawChild.hitTest(result, position: position);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final progress = _animation.value;
    if (_updateChildOffset(progress, _flightBounds)) {
      transform.translateByDouble(
        _childOffset.dx,
        _childOffset.dy,
        0,
        1,
      );
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('layoutCount', _debugLayoutCount))
      ..add(DiagnosticsProperty<Rect>('flightBounds', _flightBounds))
      ..add(DiagnosticsProperty<Rect>('paintBounds', paintBounds))
      ..add(DiagnosticsProperty<Offset>('childOffset', _childOffset));
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

  bool _updateChildOffset(double progress, Rect flightBounds) {
    final rawChild = child;
    if (rawChild == null || flightBounds.isEmpty) return false;
    final plannedRect = _plan.childRectAt(progress);
    if (plannedRect.isEmpty) return false;
    final childRect = plannedRect.shift(
      flightBounds.topLeft,
    );
    _childOffset = childRect.topLeft;
    return true;
  }

  void _handleFlightChanged() {
    final progress = _animation.value;
    final selectionChanged = _plan.rawSelectionChangesBetween(
      _lastProgress,
      progress,
    );
    _lastProgress = progress;
    if (_plan.requiresFrameLayout || selectionChanged) {
      markNeedsLayout();
      return;
    }
    markNeedsPaint();
  }
}
