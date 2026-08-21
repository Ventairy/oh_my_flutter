part of 'maybe_safe_area.dart';

class _RenderMaybeSafeArea extends RenderProxyBox {
  _RenderMaybeSafeArea({
    required double initialDevicePixelRatio,
    required _MaybeSafeAreaEdges initialEnabledEdges,
    required EdgeInsets initialViewPadding,
    required Size initialViewSize,
  }) : _devicePixelRatio = initialDevicePixelRatio,
       _enabledEdges = initialEnabledEdges,
       _viewPadding = initialViewPadding,
       _viewSize = initialViewSize;

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _markGeometryChanged();
  }

  _MaybeSafeAreaEdges get enabledEdges => _enabledEdges;
  _MaybeSafeAreaEdges _enabledEdges;
  set enabledEdges(_MaybeSafeAreaEdges value) {
    if (value == _enabledEdges) return;
    final hadEnabledPadding = _hasEnabledPadding;
    _enabledEdges = value;
    _markGeometryChanged(
      compositingChanged: hadEnabledPadding != _hasEnabledPadding,
    );
  }

  EdgeInsets get viewPadding => _viewPadding;
  EdgeInsets _viewPadding;
  set viewPadding(EdgeInsets value) {
    if (value == _viewPadding) return;
    final hadEnabledPadding = _hasEnabledPadding;
    _viewPadding = value;
    _markGeometryChanged(
      compositingChanged: hadEnabledPadding != _hasEnabledPadding,
    );
  }

  Size get viewSize => _viewSize;
  Size _viewSize;
  set viewSize(Size value) {
    if (value == _viewSize) return;
    _viewSize = value;
    _markGeometryChanged();
  }

  bool get _hasEnabledPadding {
    return (_enabledEdges.left && _viewPadding.left > 0) ||
        (_enabledEdges.top && _viewPadding.top > 0) ||
        (_enabledEdges.right && _viewPadding.right > 0) ||
        (_enabledEdges.bottom && _viewPadding.bottom > 0);
  }

  void _markGeometryChanged({bool compositingChanged = false}) {
    if (compositingChanged) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _hasEnabledPadding;

  @override
  _MaybeSafeAreaLayer? get layer => super.layer as _MaybeSafeAreaLayer?;

  final Matrix4 _unadjustedToView = Matrix4.identity();
  final Matrix4 _localCorrection = Matrix4.identity();
  final _MaybeSafeAreaBounds _unadjustedBounds = _MaybeSafeAreaBounds();
  List<RenderObject>? _transformPath;

  Matrix4 get _currentTransform {
    if (!_hasEnabledPadding) return _localCorrection..setIdentity();
    final unadjustedToView = _resolveUnadjustedToView();
    if (unadjustedToView == null) {
      return layer?.lastTransform ?? (_localCorrection..setIdentity());
    }
    _unadjustedBounds.setTransformed(
      unadjustedToView,
      width: size.width,
      height: size.height,
    );
    final correctionX = _MaybeSafeAreaGeometry.horizontalCorrection(
      bounds: _unadjustedBounds,
      enabledEdges: enabledEdges,
      viewWidth: viewSize.width,
      viewHeight: viewSize.height,
      viewPaddingLeft: viewPadding.left,
      viewPaddingRight: viewPadding.right,
    );
    final correctionY = _MaybeSafeAreaGeometry.verticalCorrection(
      bounds: _unadjustedBounds,
      enabledEdges: enabledEdges,
      viewWidth: viewSize.width,
      viewHeight: viewSize.height,
      viewPaddingTop: viewPadding.top,
      viewPaddingBottom: viewPadding.bottom,
    );
    if (correctionX == 0 && correctionY == 0) {
      return _localCorrection..setIdentity();
    }
    final localCorrection = _localCorrection..setFrom(unadjustedToView);
    if (localCorrection.invert() == 0) {
      return layer?.lastTransform ?? Matrix4.identity();
    }
    localCorrection
      ..translateByDouble(correctionX, correctionY, 0, 1)
      ..multiply(unadjustedToView);
    return localCorrection;
  }

  Matrix4? _resolveUnadjustedToView() {
    final path = _validatedTransformPath();
    if (path == null) return null;
    final result = _unadjustedToView..setIdentity();
    for (var index = path.length - 2; index > 0; index -= 1) {
      path[index].applyPaintTransform(path[index - 1], result);
    }
    return result;
  }

  List<RenderObject>? _validatedTransformPath() {
    final rootNode = owner?.rootNode;
    if (rootNode == null) return null;
    final cachedPath = _transformPath;
    if (cachedPath != null &&
        cachedPath.isNotEmpty &&
        identical(cachedPath.first, this) &&
        identical(cachedPath.last, rootNode)) {
      var valid = true;
      for (var index = 0; index + 1 < cachedPath.length; index += 1) {
        if (!identical(cachedPath[index].parent, cachedPath[index + 1])) {
          valid = false;
          break;
        }
      }
      if (valid) return cachedPath;
    }

    final path = (cachedPath ?? <RenderObject>[])..clear();
    RenderObject? node = this;
    while (node != null) {
      path.add(node);
      if (identical(node, rootNode)) {
        _transformPath = path;
        return path;
      }
      node = node.parent;
    }
    return null;
  }

  @override
  void detach() {
    _transformPath = null;
    layer = null;
    super.detach();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _currentTransform,
      position: position,
      hitTest: (result, transformed) {
        if (!(layer?.contains(transformed) ?? true)) {
          return false;
        }
        return super.hitTestChildren(result, position: transformed);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    if (!_hasEnabledPadding) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer ??= _MaybeSafeAreaLayer();
    layer!
      ..enabledEdges = _enabledEdges
      ..unadjustedOffset = offset
      ..viewWidth = _viewSize.width * _devicePixelRatio
      ..viewHeight = _viewSize.height * _devicePixelRatio
      ..viewPaddingLeft = _viewPadding.left * _devicePixelRatio
      ..viewPaddingTop = _viewPadding.top * _devicePixelRatio
      ..viewPaddingRight = _viewPadding.right * _devicePixelRatio
      ..viewPaddingBottom = _viewPadding.bottom * _devicePixelRatio
      ..widgetWidth = size.width
      ..widgetHeight = size.height;
    context.pushLayer(
      layer!,
      super.paint,
      Offset.zero,
      childPaintBounds: const Rect.fromLTRB(
        double.negativeInfinity,
        double.negativeInfinity,
        double.infinity,
        double.infinity,
      ),
    );
    assert(() {
      layer!.debugCreator = debugCreator;
      return true;
    }(), 'MaybeSafeArea could not attach its debug metadata.');
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_currentTransform);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    final localClip = layer?.localClipBounds;
    return localClip == null ? null : MatrixUtils.transformRect(_currentTransform, localClip);
  }
}
