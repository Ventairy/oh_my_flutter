part of 'morph.dart';

class _RenderMorphPositionedFlight extends RenderProxyBox {
  _RenderMorphPositionedFlight(
    this._animation,
    this._geometry,
    this._sourceBounds,
    this._destinationBounds,
  );

  Animation<double> _animation;
  _MorphFlightGeometry? _geometry;
  Rect _sourceBounds;
  Rect _destinationBounds;
  Offset _childOffset = Offset.zero;
  BoxConstraints? _childConstraints;
  int _debugLayoutCount = 0;

  @override
  Rect get paintBounds {
    final child = this.child;
    return child == null ? Rect.zero : child.paintBounds.shift(_childOffset);
  }

  Animation<double> get animation => _animation;

  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) _animation.removeListener(_handleFlightChanged);
    _animation = value;
    if (attached) _animation.addListener(_handleFlightChanged);
    _handleFlightChanged();
  }

  _MorphFlightGeometry? get geometry => _geometry;

  set geometry(_MorphFlightGeometry? value) {
    if (identical(value, _geometry)) return;
    if (attached) _geometry?.removeListener(_handleFlightChanged);
    _geometry = value;
    if (attached) _geometry?.addListener(_handleFlightChanged);
    _handleFlightChanged();
  }

  Rect get sourceBounds => _sourceBounds;

  set sourceBounds(Rect value) {
    if (value == _sourceBounds) return;
    _sourceBounds = value;
    _handleFlightChanged();
  }

  Rect get destinationBounds => _destinationBounds;

  set destinationBounds(Rect value) {
    if (value == _destinationBounds) return;
    _destinationBounds = value;
    _handleFlightChanged();
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
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.biggest.isFinite ? constraints.biggest : constraints.constrain(Size.zero);
  }

  @override
  void performLayout() {
    assert(() {
      _debugLayoutCount += 1;
      return true;
    }(), 'Fallback flight layout should be observable in debug mode.');
    size = computeDryLayout(constraints);
    final child = this.child;
    if (child == null) return;
    final childSize = _childSizeAtCurrentProgress();
    final childConstraints = _childConstraints?.smallest == childSize
        ? _childConstraints!
        : _childConstraints = BoxConstraints.tight(childSize);
    child.layout(childConstraints);
    _childOffset = _childOffsetAtCurrentProgress();
  }

  void _handleFlightChanged() {
    final childConstraints = _childConstraints;
    final source = _geometry?.sourceBounds ?? _sourceBounds;
    final destination = _geometry?.destinationBounds ?? _destinationBounds;
    final progress = _animation.value;
    final width = math.max(
      0,
      ui.lerpDouble(source.width, destination.width, progress)!,
    );
    final height = math.max(
      0,
      ui.lerpDouble(source.height, destination.height, progress)!,
    );
    if (childConstraints == null || childConstraints.maxWidth != width || childConstraints.maxHeight != height) {
      markNeedsLayout();
      return;
    }
    final childOffset = Offset(
      ui.lerpDouble(source.left, destination.left, progress)!,
      ui.lerpDouble(source.top, destination.top, progress)!,
    );
    if (childOffset == _childOffset) return;
    _childOffset = childOffset;
    markNeedsPaint();
  }

  Size _childSizeAtCurrentProgress() {
    final source = _geometry?.sourceBounds ?? _sourceBounds;
    final destination = _geometry?.destinationBounds ?? _destinationBounds;
    final progress = _animation.value;
    return Size(
      math.max(
        0,
        ui.lerpDouble(source.width, destination.width, progress)!,
      ),
      math.max(
        0,
        ui.lerpDouble(source.height, destination.height, progress)!,
      ),
    );
  }

  Offset _childOffsetAtCurrentProgress() {
    final source = _geometry?.sourceBounds ?? _sourceBounds;
    final destination = _geometry?.destinationBounds ?? _destinationBounds;
    final progress = _animation.value;
    return Offset(
      ui.lerpDouble(source.left, destination.left, progress)!,
      ui.lerpDouble(source.top, destination.top, progress)!,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(child, offset + _childOffset);
  }

  @override
  bool hitTestChildren(
    BoxHitTestResult result, {
    required Offset position,
  }) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _childOffset,
      position: position,
      hitTest: (result, transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(
      _childOffset.dx,
      _childOffset.dy,
      0,
      1,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('layoutCount', _debugLayoutCount))
      ..add(DiagnosticsProperty<Offset>('childOffset', _childOffset));
  }
}
