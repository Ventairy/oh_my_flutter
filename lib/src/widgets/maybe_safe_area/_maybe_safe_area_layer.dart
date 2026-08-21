part of 'maybe_safe_area.dart';

class _MaybeSafeAreaLayer extends ContainerLayer {
  MaybeSafeAreaBehavior behavior = MaybeSafeAreaBehavior.live;
  _MaybeSafeAreaEdges enabledEdges = const (
    left: true,
    top: true,
    right: true,
    bottom: true,
  );
  Offset unadjustedOffset = Offset.zero;
  double viewWidth = 0;
  double viewHeight = 0;
  double viewPaddingLeft = 0;
  double viewPaddingTop = 0;
  double viewPaddingRight = 0;
  double viewPaddingBottom = 0;
  double widgetWidth = 0;
  double widgetHeight = 0;

  final List<ContainerLayer> _ancestorLayers = <ContainerLayer>[];
  final Matrix4 _parentToView = Matrix4.identity();
  final Matrix4 _unadjustedTransform = Matrix4.identity();
  final Matrix4 _correctedTransform = Matrix4.identity();
  final Matrix4 _viewToParent = Matrix4.identity();
  final Matrix4 _lastRelativeTransform = Matrix4.identity();
  final Matrix4 _lastTransform = Matrix4.identity();
  final Matrix4 _preservedCorrection = Matrix4.identity();
  final Matrix4 _invertedTransform = Matrix4.identity();
  final Matrix4 _clipInverse = Matrix4.identity();
  final _MaybeSafeAreaBounds _unadjustedBounds = _MaybeSafeAreaBounds();
  final _MaybeSafeAreaBounds _correctedBounds = _MaybeSafeAreaBounds();
  final ui.Path _clipPath = ui.Path();
  Rect? _localClipBounds;
  Rect? _localClipRect;
  bool _hasInvertedTransform = false;
  bool _hasPreservedCorrection = false;
  bool _usesClipPath = false;

  Rect? get localClipBounds => _localClipBounds;

  bool contains(Offset position) {
    final clipBounds = _localClipBounds;
    if (clipBounds == null || !clipBounds.contains(position)) {
      return clipBounds == null;
    }
    return !_usesClipPath || _clipPath.contains(position);
  }

  Matrix4 get lastTransform => _lastTransform;

  bool hasPreservedCorrectionFor({required Size widgetSize}) {
    return _hasPreservedCorrection && widgetWidth == widgetSize.width && widgetHeight == widgetSize.height;
  }

  void configure({
    required MaybeSafeAreaBehavior behavior,
    required _MaybeSafeAreaEdges enabledEdges,
    required Offset unadjustedOffset,
    required double viewWidth,
    required double viewHeight,
    required double viewPaddingLeft,
    required double viewPaddingTop,
    required double viewPaddingRight,
    required double viewPaddingBottom,
    required double widgetWidth,
    required double widgetHeight,
  }) {
    final geometryChanged =
        this.behavior != behavior ||
        this.enabledEdges != enabledEdges ||
        this.viewWidth != viewWidth ||
        this.viewHeight != viewHeight ||
        this.viewPaddingLeft != viewPaddingLeft ||
        this.viewPaddingTop != viewPaddingTop ||
        this.viewPaddingRight != viewPaddingRight ||
        this.viewPaddingBottom != viewPaddingBottom ||
        this.widgetWidth != widgetWidth ||
        this.widgetHeight != widgetHeight;
    final offsetChanged = this.unadjustedOffset != unadjustedOffset;
    this.behavior = behavior;
    this.enabledEdges = enabledEdges;
    this.unadjustedOffset = unadjustedOffset;
    this.viewWidth = viewWidth;
    this.viewHeight = viewHeight;
    this.viewPaddingLeft = viewPaddingLeft;
    this.viewPaddingTop = viewPaddingTop;
    this.viewPaddingRight = viewPaddingRight;
    this.viewPaddingBottom = viewPaddingBottom;
    this.widgetWidth = widgetWidth;
    this.widgetHeight = widgetHeight;
    if (geometryChanged) _hasPreservedCorrection = false;
    if (!alwaysNeedsAddToScene && (geometryChanged || offsetChanged)) {
      markNeedsAddToScene();
    }
  }

  void invalidatePreservedCorrection() {
    _hasPreservedCorrection = false;
    if (!alwaysNeedsAddToScene) markNeedsAddToScene();
  }

  @override
  bool get alwaysNeedsAddToScene => switch (behavior) {
    MaybeSafeAreaBehavior.live => true,
    MaybeSafeAreaBehavior.preserve => false,
  };

  @override
  void addToScene(ui.SceneBuilder builder) {
    if (_hasPreservedCorrection) {
      _applyPreservedCorrection();
      _updateInteractionTransforms();
      _addTransformedChildrenToScene(builder);
      return;
    }
    _resolveParentToViewTransform();
    _unadjustedTransform
      ..setFrom(_parentToView)
      ..translateByDouble(
        unadjustedOffset.dx,
        unadjustedOffset.dy,
        0,
        1,
      );
    _unadjustedBounds.setTransformed(
      _unadjustedTransform,
      width: widgetWidth,
      height: widgetHeight,
    );
    final correctionX = _MaybeSafeAreaGeometry.horizontalCorrection(
      bounds: _unadjustedBounds,
      enabledEdges: enabledEdges,
      viewWidth: viewWidth,
      viewHeight: viewHeight,
      viewPaddingLeft: viewPaddingLeft,
      viewPaddingRight: viewPaddingRight,
    );
    final correctionY = _MaybeSafeAreaGeometry.verticalCorrection(
      bounds: _unadjustedBounds,
      enabledEdges: enabledEdges,
      viewWidth: viewWidth,
      viewHeight: viewHeight,
      viewPaddingTop: viewPaddingTop,
      viewPaddingBottom: viewPaddingBottom,
    );
    _viewToParent.setFrom(_parentToView);
    if (_viewToParent.invert() == 0) {
      _setUnadjustedRelativeTransform();
      _clearClip();
    } else {
      final correctedBounds = _correctedBounds
        ..left = _unadjustedBounds.left + correctionX
        ..top = _unadjustedBounds.top + correctionY
        ..right = _unadjustedBounds.right + correctionX
        ..bottom = _unadjustedBounds.bottom + correctionY;
      final clipRequired = _updateClip(
        correctedBounds: correctedBounds,
        correctionX: correctionX,
        correctionY: correctionY,
      );
      if (!clipRequired) {
        _setRelativeTransform(correctionX, correctionY);
      }
    }
    _updateInteractionTransforms();
    if (!alwaysNeedsAddToScene) {
      _preservedCorrection.setFrom(_lastTransform);
      _hasPreservedCorrection = true;
    }
    _addTransformedChildrenToScene(builder);
  }

  void _applyPreservedCorrection() {
    _lastRelativeTransform
      ..setIdentity()
      ..translateByDouble(
        unadjustedOffset.dx,
        unadjustedOffset.dy,
        0,
        1,
      )
      ..multiply(_preservedCorrection);
  }

  void _setUnadjustedRelativeTransform() {
    _lastRelativeTransform
      ..setIdentity()
      ..translateByDouble(unadjustedOffset.dx, unadjustedOffset.dy, 0, 1);
  }

  void _setRelativeTransform(double correctionX, double correctionY) {
    final storage = _parentToView.storage;
    final a = storage[0];
    final b = storage[1];
    final c = storage[4];
    final d = storage[5];
    final determinant = a * d - b * c;
    final ordinaryAffine =
        storage[2] == 0.0 &&
        storage[3] == 0.0 &&
        storage[6] == 0.0 &&
        storage[7] == 0.0 &&
        storage[8] == 0.0 &&
        storage[9] == 0.0 &&
        storage[11] == 0.0 &&
        storage[15] == 1.0 &&
        determinant.isFinite &&
        determinant != 0.0 &&
        storage[10].isFinite &&
        storage[10] != 0.0;
    if (ordinaryAffine) {
      final localX = (d * correctionX - c * correctionY) / determinant;
      final localY = (-b * correctionX + a * correctionY) / determinant;
      if (localX.isFinite && localY.isFinite) {
        _lastRelativeTransform
          ..setIdentity()
          ..translateByDouble(
            unadjustedOffset.dx + localX,
            unadjustedOffset.dy + localY,
            0,
            1,
          );
        return;
      }
    }
    _correctedTransform
      ..setIdentity()
      ..translateByDouble(correctionX, correctionY, 0, 1)
      ..multiply(_unadjustedTransform);
    _lastRelativeTransform
      ..setFrom(_viewToParent)
      ..multiply(_correctedTransform);
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    transform.multiply(_lastRelativeTransform);
  }

  @override
  Rect? describeClipBounds() => _localClipBounds;

  @override
  bool findAnnotations<S extends Object>(
    AnnotationResult<S> result,
    Offset localPosition, {
    required bool onlyFirst,
  }) {
    if (!_hasInvertedTransform) return false;
    final transformed = MatrixUtils.transformPoint(
      _invertedTransform,
      localPosition,
    );
    if (!contains(transformed)) return false;
    return super.findAnnotations(
      result,
      transformed,
      onlyFirst: onlyFirst,
    );
  }

  void _resolveParentToViewTransform() {
    _ancestorLayers
      ..clear()
      ..add(this);
    for (var ancestor = parent; ancestor != null; ancestor = ancestor.parent) {
      _ancestorLayers.add(ancestor);
    }
    _parentToView.setIdentity();
    for (var index = _ancestorLayers.length - 1; index > 0; index -= 1) {
      _ancestorLayers[index].applyTransform(
        _ancestorLayers[index - 1],
        _parentToView,
      );
    }
  }

  void _updateInteractionTransforms() {
    _lastTransform
      ..setIdentity()
      ..translateByDouble(
        -unadjustedOffset.dx,
        -unadjustedOffset.dy,
        0,
        1,
      )
      ..multiply(_lastRelativeTransform);
    _invertedTransform.setFrom(_lastRelativeTransform);
    _hasInvertedTransform = _invertedTransform.invert() != 0;
  }

  void _addTransformedChildrenToScene(ui.SceneBuilder builder) {
    engineLayer = builder.pushTransform(
      _lastRelativeTransform.storage,
      oldLayer: engineLayer as ui.TransformEngineLayer?,
    );
    final clipRect = _localClipRect;
    if (clipRect != null) {
      builder.pushClipRect(clipRect, clipBehavior: ui.Clip.hardEdge);
    } else if (_usesClipPath) {
      builder.pushClipPath(_clipPath, clipBehavior: ui.Clip.hardEdge);
    }
    addChildrenToScene(builder);
    if (clipRect != null || _usesClipPath) builder.pop();
    builder.pop();
  }

  bool _updateClip({
    required _MaybeSafeAreaBounds correctedBounds,
    required double correctionX,
    required double correctionY,
  }) {
    final safeLeft = enabledEdges.left ? viewPaddingLeft : 0.0;
    final safeTop = enabledEdges.top ? viewPaddingTop : 0.0;
    final safeRight = viewWidth - (enabledEdges.right ? viewPaddingRight : 0.0);
    final safeBottom = viewHeight - (enabledEdges.bottom ? viewPaddingBottom : 0.0);
    final visibleLeft = safeLeft > correctionX ? safeLeft : correctionX;
    final visibleTop = safeTop > correctionY ? safeTop : correctionY;
    final correctedViewRight = viewWidth + correctionX;
    final correctedViewBottom = viewHeight + correctionY;
    final visibleRight = safeRight < correctedViewRight ? safeRight : correctedViewRight;
    final visibleBottom = safeBottom < correctedViewBottom ? safeBottom : correctedViewBottom;
    if (visibleRight <= visibleLeft || visibleBottom <= visibleTop) {
      _setRectClip(Rect.zero);
      _setRelativeTransform(correctionX, correctionY);
      return true;
    }

    if (correctedBounds.left >= visibleLeft &&
        correctedBounds.top >= visibleTop &&
        correctedBounds.right <= visibleRight &&
        correctedBounds.bottom <= visibleBottom) {
      _clearClip();
      return false;
    }

    _correctedTransform
      ..setIdentity()
      ..translateByDouble(correctionX, correctionY, 0, 1)
      ..multiply(_unadjustedTransform);
    _clipInverse.setFrom(_correctedTransform);
    if (_clipInverse.invert() == 0) {
      _clearClip();
      _setUnadjustedRelativeTransform();
      return false;
    }
    final topLeft = MatrixUtils.transformPoint(
      _clipInverse,
      Offset(visibleLeft, visibleTop),
    );
    final topRight = MatrixUtils.transformPoint(
      _clipInverse,
      Offset(visibleRight, visibleTop),
    );
    final bottomRight = MatrixUtils.transformPoint(
      _clipInverse,
      Offset(visibleRight, visibleBottom),
    );
    final bottomLeft = MatrixUtils.transformPoint(
      _clipInverse,
      Offset(visibleLeft, visibleBottom),
    );
    if (topLeft.dy == topRight.dy &&
        topRight.dx == bottomRight.dx &&
        bottomRight.dy == bottomLeft.dy &&
        bottomLeft.dx == topLeft.dx) {
      _setRectClip(
        Rect.fromLTRB(
          topLeft.dx < bottomRight.dx ? topLeft.dx : bottomRight.dx,
          topLeft.dy < bottomRight.dy ? topLeft.dy : bottomRight.dy,
          topLeft.dx > bottomRight.dx ? topLeft.dx : bottomRight.dx,
          topLeft.dy > bottomRight.dy ? topLeft.dy : bottomRight.dy,
        ),
      );
      _setRelativeTransform(correctionX, correctionY);
      return true;
    }
    _clipPath
      ..reset()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();
    _localClipBounds = _clipPath.getBounds();
    _localClipRect = null;
    _usesClipPath = true;
    _setRelativeTransform(correctionX, correctionY);
    return true;
  }

  void _setRectClip(Rect clip) {
    _localClipBounds = clip;
    _localClipRect = clip;
    _usesClipPath = false;
  }

  void _clearClip() {
    _localClipBounds = null;
    _localClipRect = null;
    _usesClipPath = false;
  }
}
