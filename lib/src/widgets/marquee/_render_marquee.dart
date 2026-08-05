part of 'marquee.dart';

class _RenderMarquee extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MarqueeParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MarqueeParentData>,
        DebugOverflowIndicatorMixin {
  _RenderMarquee({
    required this._animation,
    required this._direction,
    required this._spacing,
    required this._width,
    required this._height,
    required this._staticPosition,
    required this._interactive,
    required this._infinity,
    required this._sourceChildCount,
    required this._onRequiredChildCountChanged,
  }) : _isHorizontal = _isHorizontalDirection(_direction);

  Animation<double> _animation;
  MarqueeDirection _direction;
  double _spacing;
  double? _width;
  double? _height;
  bool _staticPosition;
  bool _interactive;
  bool _infinity;
  int _sourceChildCount;
  void Function(int) _onRequiredChildCountChanged;
  bool _isHorizontal;
  double _stripMainExtent = 0;
  double _sourceMainExtent = 0;
  double _stripCrossExtent = 0;
  double _translationStart = 0;
  double _translationDistance = 0;
  double _currentTranslation = 0;
  Rect _cachedPaintBounds = Rect.zero;
  int? _lastReportedChildCount;
  final Matrix4 _firstTransform = Matrix4.identity();
  final Matrix4 _secondTransform = Matrix4.identity();
  final List<RenderBox> _childrenInPaintOrder = <RenderBox>[];
  final List<double> _sourceChildSegments = <double>[];
  bool _useFirstTransform = true;

  Animation<double> get animation => _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) _animation.removeListener(_handleAnimationChanged);
    _animation = value;
    if (attached) _animation.addListener(_handleAnimationChanged);
    _handleAnimationChanged();
  }

  MarqueeDirection get direction => _direction;
  set direction(MarqueeDirection value) {
    if (value == _direction) return;
    _direction = value;
    _isHorizontal = _isHorizontalDirection(value);
    _lastReportedChildCount = null;
    markNeedsLayout();
  }

  double get spacing => _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    _lastReportedChildCount = null;
    markNeedsLayout();
  }

  double? get width => _width;
  set width(double? value) {
    if (value == _width) return;
    _width = value;
    _lastReportedChildCount = null;
    markNeedsLayout();
  }

  double? get height => _height;
  set height(double? value) {
    if (value == _height) return;
    _height = value;
    _lastReportedChildCount = null;
    markNeedsLayout();
  }

  bool get staticPosition => _staticPosition;
  set staticPosition(bool value) {
    if (value == _staticPosition) return;
    _staticPosition = value;
    _updateTravelGeometry();
    _handleAnimationChanged();
  }

  bool get interactive => _interactive;
  set interactive(bool value) {
    if (value == _interactive) return;
    _interactive = value;
    markNeedsSemanticsUpdate();
  }

  bool get infinity => _infinity;
  set infinity(bool value) {
    if (value == _infinity) return;
    _infinity = value;
    _lastReportedChildCount = null;
    markNeedsLayout();
  }

  int get sourceChildCount => _sourceChildCount;
  set sourceChildCount(int value) {
    if (value == _sourceChildCount) return;
    _sourceChildCount = value;
    _lastReportedChildCount = null;
    markNeedsLayout();
  }

  static bool _isHorizontalDirection(MarqueeDirection direction) {
    return switch (direction) {
      MarqueeDirection.left || MarqueeDirection.right => true,
      MarqueeDirection.top || MarqueeDirection.down => false,
    };
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  Rect get paintBounds => _cachedPaintBounds;

  @override
  OffsetLayer updateCompositedLayer({
    required covariant TransformLayer? oldLayer,
  }) {
    final transform = _useFirstTransform ? _firstTransform : _secondTransform;
    _useFirstTransform = !_useFirstTransform;
    transform.setTranslationRaw(
      _isHorizontal ? _currentTranslation : 0,
      _isHorizontal ? 0 : _currentTranslation,
      0,
    );
    return (oldLayer ?? TransformLayer())..transform = transform;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MarqueeParentData) {
      child.parentData = _MarqueeParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_handleAnimationChanged);
  }

  @override
  void detach() {
    _animation.removeListener(_handleAnimationChanged);
    super.detach();
  }

  void _handleAnimationChanged() {
    _updateCurrentTranslation();
    markNeedsCompositedLayerUpdate();
    if (owner?.semanticsOwner != null) {
      markNeedsSemanticsUpdate();
    }
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    if (_isHorizontal) {
      return BoxConstraints(
        maxHeight: _height == null ? constraints.maxHeight : double.infinity,
      );
    }
    return BoxConstraints(
      maxWidth: _width == null ? constraints.maxWidth : double.infinity,
    );
  }

  void _debugCheckMainAxisConstraints(BoxConstraints constraints) {
    if (_isHorizontal && _width == null && !constraints.hasBoundedWidth) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Marquee requires a bounded width.'),
        ErrorDescription('A horizontal Marquee must receive a bounded parent width or an explicit width.'),
      ]);
    }
    if (!_isHorizontal && _height == null && !constraints.hasBoundedHeight) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Marquee requires a bounded height.'),
        ErrorDescription('A vertical Marquee must receive a bounded parent height or an explicit height.'),
      ]);
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    _debugCheckMainAxisConstraints(constraints);
    final childConstraints = _childConstraints(constraints);
    var stripCrossExtent = 0.0;
    var child = firstChild;
    while (child != null) {
      final childSize = child.getDryLayout(childConstraints);
      stripCrossExtent = math.max(
        stripCrossExtent,
        _isHorizontal ? childSize.height : childSize.width,
      );
      final parentData = child.parentData! as _MarqueeParentData;
      child = parentData.nextSibling;
    }
    return _resolveSize(constraints, stripCrossExtent: stripCrossExtent);
  }

  Size _resolveSize(
    BoxConstraints constraints, {
    required double stripCrossExtent,
  }) {
    if (_isHorizontal) {
      return constraints.constrain(
        Size(_width ?? constraints.maxWidth, _height ?? stripCrossExtent),
      );
    }
    return constraints.constrain(
      Size(_width ?? stripCrossExtent, _height ?? constraints.maxHeight),
    );
  }

  @override
  void performLayout() {
    _debugCheckMainAxisConstraints(constraints);
    final childConstraints = _childConstraints(constraints);
    var mainOffset = 0.0;
    var crossExtent = 0.0;
    var childIndex = 0;
    var sourceMainExtent = 0.0;
    var child = firstChild;
    _childrenInPaintOrder.clear();
    _sourceChildSegments.clear();
    while (child != null) {
      _childrenInPaintOrder.add(child);
      child.layout(childConstraints, parentUsesSize: true);
      final parentData = child.parentData! as _MarqueeParentData
        ..offset = _isHorizontal ? Offset(mainOffset, 0) : Offset(0, mainOffset);
      final childMainExtent = _isHorizontal ? child.size.width : child.size.height;
      mainOffset += childMainExtent;
      crossExtent = math.max(
        crossExtent,
        _isHorizontal ? child.size.height : child.size.width,
      );
      if (childIndex < _sourceChildCount) {
        _sourceChildSegments.add(childMainExtent + _spacing);
      }
      if (childIndex == _sourceChildCount - 1) {
        sourceMainExtent = mainOffset + _spacing;
      }
      child = parentData.nextSibling;
      if (child != null) mainOffset += _spacing;
      childIndex += 1;
    }
    _stripMainExtent = mainOffset;
    _sourceMainExtent = sourceMainExtent;
    _stripCrossExtent = crossExtent;
    size = _resolveSize(constraints, stripCrossExtent: _stripCrossExtent);
    _updateTravelGeometry();
    _updateCurrentTranslation();
    _cachedPaintBounds = _isHorizontal
        ? Rect.fromLTWH(
            0,
            0,
            math.max(size.width, _stripMainExtent),
            math.max(size.height, _stripCrossExtent),
          )
        : Rect.fromLTWH(
            0,
            0,
            math.max(size.width, _stripCrossExtent),
            math.max(size.height, _stripMainExtent),
          );
    _reportRequiredChildCount();
  }

  void _reportRequiredChildCount() {
    if (!_infinity) return;
    final viewportExtent = _isHorizontal ? size.width : size.height;
    var requiredChildCount = _sourceChildCount;
    if (_sourceMainExtent > 0) {
      final completeCycles = (viewportExtent / _sourceMainExtent).floor();
      requiredChildCount += completeCycles * _sourceChildCount;
      var remainingExtent = viewportExtent - completeCycles * _sourceMainExtent;
      var childIndex = 0;
      while (remainingExtent > precisionErrorTolerance && childIndex < _sourceChildSegments.length) {
        remainingExtent -= _sourceChildSegments[childIndex];
        requiredChildCount += 1;
        childIndex += 1;
      }
    }
    if (requiredChildCount == _lastReportedChildCount) return;
    _lastReportedChildCount = requiredChildCount;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached || requiredChildCount != _lastReportedChildCount) return;
      _onRequiredChildCountChanged(requiredChildCount);
    });
  }

  void _updateTravelGeometry() {
    if (_staticPosition) {
      _translationStart = 0;
      _translationDistance = 0;
      return;
    }
    if (_infinity) {
      final travelExtent = _sourceMainExtent;
      switch (_direction) {
        case MarqueeDirection.left || MarqueeDirection.top:
          _translationStart = 0;
          _translationDistance = -travelExtent;
        case MarqueeDirection.right || MarqueeDirection.down:
          _translationStart = -travelExtent;
          _translationDistance = travelExtent;
      }
      return;
    }
    final viewportExtent = _isHorizontal ? size.width : size.height;
    final travelExtent = viewportExtent + _stripMainExtent;
    switch (_direction) {
      case MarqueeDirection.left || MarqueeDirection.top:
        _translationStart = viewportExtent;
        _translationDistance = -travelExtent;
      case MarqueeDirection.right || MarqueeDirection.down:
        _translationStart = -_stripMainExtent;
        _translationDistance = travelExtent;
    }
  }

  void _updateCurrentTranslation() {
    _currentTranslation = _translationStart + _translationDistance * _animation.value;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _childrenInPaintOrder) {
      final parentData = child.parentData! as _MarqueeParentData;
      context.paintChild(child, offset + parentData.offset);
    }

    assert(() {
      final crossOverflow = _stripCrossExtent - (_isHorizontal ? size.height : size.width);
      if (crossOverflow > precisionErrorTolerance) {
        final containerRect = Offset.zero & size;
        final childRect = _isHorizontal
            ? Rect.fromLTWH(0, 0, size.width, _stripCrossExtent)
            : Rect.fromLTWH(0, 0, _stripCrossExtent, size.height);
        paintOverflowIndicator(context, offset, containerRect, childRect);
      }
      return true;
    }(), 'Marquee overflow indicators are only painted in debug mode.');
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_interactive) return false;
    final translation = _currentTranslation;
    final mainPosition = (_isHorizontal ? position.dx : position.dy) - translation;
    var low = 0;
    var high = _childrenInPaintOrder.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      final child = _childrenInPaintOrder[middle];
      final parentData = child.parentData! as _MarqueeParentData;
      final childStart = _isHorizontal ? parentData.offset.dx : parentData.offset.dy;
      if (mainPosition < childStart) {
        high = middle - 1;
        continue;
      }
      final childExtent = _isHorizontal ? child.size.width : child.size.height;
      if (mainPosition >= childStart + childExtent) {
        low = middle + 1;
        continue;
      }
      final paintOffset = _isHorizontal
          ? Offset(parentData.offset.dx + translation, parentData.offset.dy)
          : Offset(parentData.offset.dx, parentData.offset.dy + translation);
      return result.addWithPaintOffset(
        offset: paintOffset,
        position: position,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      );
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final parentData = child.parentData! as _MarqueeParentData;
    transform.translateByDouble(
      parentData.offset.dx + (_isHorizontal ? _currentTranslation : 0),
      parentData.offset.dy + (_isHorizontal ? 0 : _currentTranslation),
      0,
      1,
    );
  }
}
