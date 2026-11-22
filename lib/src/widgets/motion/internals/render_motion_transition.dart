part of '../motion.dart';

/// Paints one widget through a composed list of motion effects.
class _RenderMotionTransition extends RenderProxyBox implements RestingPaintTransform {
  new({required List<_MotionApplication> applications})
    : _applications = applications,
      _renderEffects = applications.map(_MotionRenderEffect.forMotion).toList(growable: false) {
    _updateMotionState();
  }

  // On Android, Flutter exposes shader image filters on Impeller only.
  static final bool _hasSkiaFilters = !ui.ImageFilter.isShaderFilterSupported;

  final _blur = _MotionBlur();
  late ui.ImageFilter _composedFilter;
  ui.ImageFilter? _composedGaussian;
  int? _composedAlpha;
  final _opacityLayer = LayerHandle<OpacityLayer>();
  final _transformLayer = LayerHandle<TransformLayer>();
  final Matrix4 _paintTransform = Matrix4.identity();
  final MotionEffectTransform _effectTransform = MotionEffectTransform._();
  late final VoidCallback _animationListener = _updateMotionState;

  List<_MotionApplication> get applications => _applications;
  List<_MotionApplication> _applications;
  set applications(List<_MotionApplication> value) {
    if (listEquals(_applications, value)) {
      return;
    }
    if (attached) {
      _detachAnimations();
    }
    _applications = value;
    _renderEffects = value.map(_MotionRenderEffect.forMotion).toList(growable: false);
    if (attached) {
      _attachAnimations();
    }
    _updateMotionState();
    if (hasSize) {
      _updatePaintBounds();
    }
  }

  List<_MotionRenderEffect> _renderEffects;
  double _opacity = 1;
  double _scale = 1;
  double _cosine = 1;
  double _sine = 0;
  double _translationX = 0;
  double _translationY = 0;
  Rect _cachedPaintBounds = Rect.zero;

  int get _alpha => (_opacity.clamp(0.0, 1.0) * 255).round();

  bool get _paintsChild => child != null && !(_opacity <= 0 || _scale == 0 || !_scale.isFinite);

  bool get _usesOpacityLayer => _opacity > 0 && _opacity < 1;

  bool get _composesFade =>
      !kIsWeb &&
      defaultTargetPlatform == .android &&
      _hasSkiaFilters &&
      isRepaintBoundary &&
      !_hasTransform &&
      !child!.needsCompositing;

  bool get _hasTransform {
    return _scale != 1 || _cosine != 1 || _sine != 0 || _translationX != 0 || _translationY != 0;
  }

  @override
  bool get isRepaintBoundary => _paintsChild && _effectTransform._blurSigma > 0;

  @override
  bool get alwaysNeedsCompositing => isRepaintBoundary || (_paintsChild && _usesOpacityLayer);

  @override
  OffsetLayer updateCompositedLayer({required covariant ImageFilterLayer? oldLayer}) {
    if (oldLayer != null) {
      if (_usesOpacityLayer) _opacityLayer.layer?.alpha = _alpha;
      final transformLayer = _transformLayer.layer;
      if (_hasTransform && transformLayer != null && transformLayer.transform != _paintTransform) {
        transformLayer.transform = Matrix4.copy(_paintTransform);
      }
    }
    return (oldLayer ?? ImageFilterLayer())..imageFilter = _currentFilter();
  }

  ui.ImageFilter _currentFilter() {
    final gaussian = _blur.filter(_effectTransform._blurSigma);
    if (!_usesOpacityLayer || !_composesFade) return gaussian;
    final alpha = _alpha;
    if (alpha == 255) return gaussian;

    // Keep the child recording independent of animated opacity so Skia can
    // reuse its rasterized input. The inner filter fades the group before blur.
    if (!identical(_composedGaussian, gaussian) || _composedAlpha != alpha) {
      _composedGaussian = gaussian;
      _composedAlpha = alpha;
      _composedFilter = ui.ImageFilter.compose(
        outer: gaussian,
        inner: ui.ColorFilter.mode(Color.fromARGB(alpha, 0, 0, 0), BlendMode.dstIn),
      );
    }
    return _composedFilter;
  }

  @override
  Rect get paintBounds => _cachedPaintBounds;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _attachAnimations();
  }

  @override
  void detach() {
    _detachAnimations();
    super.detach();
  }

  @override
  void dispose() {
    _opacityLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  void performLayout() {
    super.performLayout();
    _updatePaintTransform();
    _updatePaintBounds();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null || _scale == 0 || !_scale.isFinite) {
      return false;
    }
    if (!_hasTransform) {
      return super.hitTestChildren(result, position: position);
    }
    return result.addWithPaintTransform(
      transform: _paintTransform,
      position: position,
      hitTest: (result, position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_paintsChild) {
      _opacityLayer.layer = null;
      _transformLayer.layer = null;
      return;
    }
    if (_usesOpacityLayer && !_composesFade) {
      _opacityLayer.layer = context.pushOpacity(
        offset,
        _alpha,
        _paintTransformedChild,
        oldLayer: _opacityLayer.layer,
      );
    } else {
      _opacityLayer.layer = null;
      _paintTransformedChild(context, offset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_paintTransform);
  }

  @override
  void applyRestingPaintTransform(RenderObject child, Matrix4 transform) {
    assert(identical(child, this.child), 'The child must be attached to this Motion.');
    // The proxy's child has a zero layout offset. Its animation affects paint
    // without changing that stable layout frame.
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('opacity', _opacity))
      ..add(DoubleProperty('scale', _scale))
      ..add(
        DiagnosticsProperty<Offset>(
          'translation',
          Offset(_translationX, _translationY),
        ),
      )
      ..add(
        IterableProperty<String>(
          'effects',
          _renderEffects.map(
            (effect) => effect.effect.runtimeType.toString(),
          ),
        ),
      );
  }

  void _paintTransformedChild(PaintingContext context, Offset offset) {
    if (!_hasTransform) {
      _transformLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _transformLayer.layer = context.pushTransform(
      // Under an active filter, keep the transform outside the child's
      // recording so it can be updated together with the filter.
      isRepaintBoundary || child!.needsCompositing,
      offset,
      _paintTransform,
      super.paint,
      oldLayer: _transformLayer.layer,
    );
  }

  void _updateMotionState() {
    final previouslyNeededCompositing = alwaysNeedsCompositing;
    final wasRepaintBoundary = isRepaintBoundary;
    final paintedChild = _paintsChild;
    final usedOpacityLayer = _usesOpacityLayer;
    final hadTransform = _hasTransform;
    final previousOpacity = _opacity;
    final previousSigma = _effectTransform._blurSigma;
    _effectTransform._reset();
    for (var index = 0; index < _renderEffects.length; index += 1) {
      final effect = _renderEffects[index]..prepareFrame();
      effect.effect.apply(effect.nextProgress(), _effectTransform);
    }
    final transformChanged =
        _scale != _effectTransform._scale ||
        _cosine != _effectTransform._cosine ||
        _sine != _effectTransform._sine ||
        _translationX != _effectTransform._translationX ||
        _translationY != _effectTransform._translationY;
    _opacity = _effectTransform._opacity;
    _scale = _effectTransform._scale;
    _cosine = _effectTransform._cosine;
    _sine = _effectTransform._sine;
    _translationX = _effectTransform._translationX;
    _translationY = _effectTransform._translationY;

    final boundaryChanged = wasRepaintBoundary != isRepaintBoundary;
    if (boundaryChanged || previouslyNeededCompositing != alwaysNeedsCompositing) {
      markNeedsCompositingBitsUpdate();
    }
    if (transformChanged) {
      if (hasSize) _updatePaintTransform();
      if (owner?.semanticsOwner != null) markNeedsSemanticsUpdate();
    }

    if (boundaryChanged ||
        paintedChild != _paintsChild ||
        (_paintsChild && (hadTransform != _hasTransform || usedOpacityLayer != _usesOpacityLayer))) {
      markNeedsPaint();
    } else if (_paintsChild &&
        (transformChanged || previousOpacity != _opacity || previousSigma != _effectTransform._blurSigma)) {
      if (isRepaintBoundary) {
        markNeedsCompositedLayerUpdate();
      } else {
        markNeedsPaint();
      }
    }
  }

  void _updatePaintTransform() {
    final storage = _paintTransform.storage;
    final scaledCosine = _scale * _cosine;
    final scaledSine = _scale * _sine;
    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;
    storage[0] = scaledCosine;
    storage[1] = scaledSine;
    storage[4] = -scaledSine;
    storage[5] = scaledCosine;
    storage[12] = _translationX + (1 - scaledCosine) * halfWidth + scaledSine * halfHeight;
    storage[13] = _translationY - scaledSine * halfWidth + (1 - scaledCosine) * halfHeight;
  }

  void _updatePaintBounds() {
    _cachedPaintBounds = _MotionRenderEffect.paintBoundsFor(size, _renderEffects.map((effect) => effect.bounds));
  }

  void _attachAnimations() {
    for (final effect in _renderEffects) {
      effect.animation.addListener(_animationListener);
    }
  }

  void _detachAnimations() {
    for (final effect in _renderEffects) {
      effect.animation.removeListener(_animationListener);
    }
  }
}
