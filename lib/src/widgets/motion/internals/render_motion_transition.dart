part of '../motion.dart';

/// Paints one widget through a composed list of motion effects.
class _RenderMotionTransition extends RenderProxyBox {
  _RenderMotionTransition({required List<_MotionApplication> applications})
    : _applications = applications,
      _renderEffects = applications.map(_MotionRenderEffect.forMotion).toList(growable: false) {
    _updateMotionState();
  }

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
  double _translationX = 0;
  double _translationY = 0;
  Rect _cachedPaintBounds = Rect.zero;
  int _paintMode = -1;

  bool get _usesOpacityLayer => _opacity > 0 && _opacity < 1;

  bool get _hasTransform {
    return _scale != 1 || _translationX != 0 || _translationY != 0;
  }

  @override
  bool get alwaysNeedsCompositing {
    return child != null && _usesOpacityLayer;
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
    if (child == null || _opacity <= 0 || _scale == 0 || !_scale.isFinite) {
      layer = null;
      _paintMode = 0;
      return;
    }

    final usesOpacity = _usesOpacityLayer;
    final hasTransform = _hasTransform;
    final nextPaintMode = (usesOpacity ? 2 : 0) | (hasTransform ? 1 : 0);
    if (_paintMode != nextPaintMode) {
      layer = null;
      _paintMode = nextPaintMode;
    }

    switch (nextPaintMode) {
      case 0:
        super.paint(context, offset);
        layer = null;
      case 1:
        layer = context.pushTransform(
          needsCompositing,
          offset,
          _paintTransform,
          super.paint,
          oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
        );
      case 2:
        layer = context.pushOpacity(
          offset,
          (_opacity.clamp(0.0, 1.0) * 255).round(),
          super.paint,
          oldLayer: layer is OpacityLayer ? layer as OpacityLayer? : null,
        );
      case 3:
        layer = context.pushOpacity(
          offset,
          (_opacity.clamp(0.0, 1.0) * 255).round(),
          _paintTransformed,
          oldLayer: layer is OpacityLayer ? layer as OpacityLayer? : null,
        );
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_paintTransform);
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

  void _paintTransformed(PaintingContext context, Offset offset) {
    context.pushTransform(
      child!.needsCompositing,
      offset,
      _paintTransform,
      super.paint,
    );
  }

  void _updateMotionState() {
    final previouslyUsedOpacityLayer = _usesOpacityLayer;
    _effectTransform._reset();
    for (var index = 0; index < _renderEffects.length; index += 1) {
      final effect = _renderEffects[index]..prepareFrame();
      effect.effect.apply(effect.nextProgress(), _effectTransform);
    }
    _opacity = _effectTransform._opacity;
    _scale = _effectTransform._scale;
    _translationX = _effectTransform._translationX;
    _translationY = _effectTransform._translationY;
    if (previouslyUsedOpacityLayer != _usesOpacityLayer) {
      markNeedsCompositingBitsUpdate();
    }
    if (hasSize) {
      _updatePaintTransform();
    }
    markNeedsPaint();
    if (owner?.semanticsOwner != null) {
      markNeedsSemanticsUpdate();
    }
  }

  void _updatePaintTransform() {
    final storage = _paintTransform.storage;
    storage[0] = _scale;
    storage[5] = _scale;
    storage[12] = _translationX + (1 - _scale) * size.width / 2;
    storage[13] = _translationY + (1 - _scale) * size.height / 2;
  }

  void _updatePaintBounds() {
    var maximumScale = 1.0;
    var horizontalMotion = 0.0;
    var verticalMotion = 0.0;
    for (final effect in _renderEffects) {
      final bounds = effect.bounds;
      horizontalMotion += bounds.maximumAbsoluteTranslationX;
      verticalMotion += bounds.maximumAbsoluteTranslationY;
      maximumScale *= math.max(1, bounds.maximumAbsoluteScale);
    }
    final horizontalOutset = horizontalMotion * maximumScale + size.width * (maximumScale - 1) / 2;
    final verticalOutset = verticalMotion * maximumScale + size.height * (maximumScale - 1) / 2;
    _cachedPaintBounds = Rect.fromLTRB(
      -horizontalOutset,
      -verticalOutset,
      size.width + horizontalOutset,
      size.height + verticalOutset,
    );
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
