part of 'skeleton.dart';

class _RenderSkeleton extends RenderProxyBox {
  new({
    required this._enabled,
    required this._animate,
    required this._forceFrames,
    required SkeletonStyle style,
    required this._textDirection,
    required Animation<double>? blend,
  }) : _style = style,
       _blend = blend,
       super() {
    _solidSkeletonPaint.color = style.color;
    blend?.addListener(_onBlendChanged);
  }

  final Paint _solidSkeletonPaint = Paint();
  final LayerHandle<OffsetLayer> _cacheLayer = LayerHandle<OffsetLayer>();
  final LayerHandle<OpacityLayer> _contentOpacityLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<OpacityLayer> _skeletonOpacityLayer = LayerHandle<OpacityLayer>();
  final List<_SkeletonBoneSegment> _boneSegments = <_SkeletonBoneSegment>[];
  final _SkeletonPaintState _paintState = _SkeletonPaintState();

  bool _enabled;
  bool _animate;
  bool _forceFrames;
  SkeletonStyle _style;
  TextDirection _textDirection;
  Animation<double>? _blend;
  bool _cacheNeedsUpdate = true;
  bool _cacheStale = false;
  bool _effectNeedsUpdate = true;
  bool _clockListening = false;
  double _lastEffectAnimationValue = 0;

  bool get enabled => _enabled;
  bool get animate => _animate;
  bool get forceFrames => _forceFrames;
  SkeletonStyle get style => _style;
  Color get boneColor => _style.color;
  SkeletonEffect? get effect => _style.effect;
  ShapeBorder get shape => _style.shape;
  TextDirection get textDirection => _textDirection;
  Animation<double>? get blend => _blend;

  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _cacheNeedsUpdate = true;
    super.markNeedsPaint();
  }

  set blend(Animation<double>? value) {
    if (identical(value, _blend)) return;
    _blend?.removeListener(_onBlendChanged);
    _blend = value;
    value?.addListener(_onBlendChanged);
    markNeedsCompositingBitsUpdate();
    super.markNeedsPaint();
  }

  void _onBlendChanged() {
    final blendValue = _blend?.value;
    final contentLayer = _contentOpacityLayer.layer;
    final skeletonLayer = _skeletonOpacityLayer.layer;
    if (blendValue != null && blendValue > 0 && blendValue < 1 && contentLayer != null && skeletonLayer != null) {
      contentLayer.alpha = ui.Color.getAlphaFromOpacity(blendValue);
      skeletonLayer.alpha = ui.Color.getAlphaFromOpacity(1 - blendValue);
      return;
    }
    super.markNeedsPaint();
  }

  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    if (value) {
      if (_cacheLayer.layer == null || _cacheStale) _cacheNeedsUpdate = true;
      _cacheStale = false;
    }
    _effectNeedsUpdate = true;
    if (!value && _blend == null) {
      _cacheLayer.layer = null;
      _boneSegments.clear();
    }
    markNeedsCompositingBitsUpdate();
    super.markNeedsPaint();
  }

  set style(SkeletonStyle value) {
    if (value == _style) return;
    final previousMode = _segmentModeFor(_style.effect);
    final nextMode = _segmentModeFor(value.effect);
    final geometryChanged =
        value.shape != _style.shape ||
        nextMode != previousMode ||
        nextMode == _SkeletonBoneSegmentMode.staticPicture ||
        (nextMode == _SkeletonBoneSegmentMode.fade && value.color != _style.color);
    _style = value;
    _solidSkeletonPaint.color = value.color;
    _cacheNeedsUpdate = _cacheNeedsUpdate || geometryChanged;
    _effectNeedsUpdate = true;
    if (_cacheNeedsUpdate) {
      super.markNeedsPaint();
    } else {
      markNeedsCompositedLayerUpdate();
    }
  }

  set animate(bool value) {
    if (value == _animate) return;
    _animate = value;
    _syncClockRegistration();
    _effectNeedsUpdate = true;
    if (_cacheNeedsUpdate) {
      super.markNeedsPaint();
    } else {
      markNeedsCompositedLayerUpdate();
    }
  }

  set forceFrames(bool value) {
    if (value == _forceFrames) return;
    _forceFrames = value;
    if (_clockListening) {
      _SkeletonAnimationClock.instance.addListener(
        _handleEffectTick,
        forceFrames: value,
      );
    }
  }

  @override
  bool get alwaysNeedsCompositing => _enabled || _blend != null;

  @override
  bool get isRepaintBoundary => _enabled || _blend != null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncClockRegistration();
  }

  @override
  void detach() {
    _stopClockListening();
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _cacheNeedsUpdate = true;
  }

  @override
  void markNeedsPaint() {
    if (_enabled) {
      _cacheNeedsUpdate = true;
    } else if (_cacheLayer.layer != null) {
      _cacheStale = true;
    }
    _syncClockRegistration();
    super.markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final blendValue = _blend?.value;
    final blendStatus = _blend?.status;
    final transitioning = blendStatus == AnimationStatus.forward || blendStatus == AnimationStatus.reverse;
    if (!transitioning) {
      _contentOpacityLayer.layer = null;
      _skeletonOpacityLayer.layer = null;
    }
    if (blendValue == null && !_enabled || blendValue == 1 && !transitioning) {
      if (!_enabled) {
        _cacheLayer.layer = null;
        _boneSegments.clear();
      }
      super.paint(context, offset);
      return;
    }

    final bounds = Offset.zero & size;
    final effectT = _effectAnimationValue();
    final skeletonPaint = _buildSkeletonPaint(bounds, t: effectT);
    final cacheLayer = _cacheLayer.layer ?? OffsetLayer();
    _cacheLayer.layer = cacheLayer;
    cacheLayer.offset = offset;

    if (_cacheNeedsUpdate) {
      cacheLayer.removeAllChildren();
      _boneSegments.clear();

      final skeletonContext = _SkeletonPaintingContext(
        cacheLayer,
        bounds,
        _paintState,
        _boneSegments,
        skeletonPaint,
        _style,
        _SkeletonBoneShape(_style.shape, _textDirection),
      );
      super.paint(skeletonContext, Offset.zero);
      skeletonContext.finish();
      _cacheNeedsUpdate = false;
      _cacheStale = false;
      if (_style.effect is SkeletonShimmerEffect) {
        _updateRetainedEffect(skeletonPaint);
      }
      if (_boneSegments.isEmpty) {
        _stopClockListening();
      } else {
        _syncClockRegistration();
      }
    } else if (_effectNeedsUpdate) {
      _updateRetainedEffect(skeletonPaint);
    }

    _effectNeedsUpdate = false;
    if (!transitioning) {
      context.addLayer(cacheLayer);
    } else {
      // Capture bones before painting live content. Both passes visit the same
      // child, whose composited layers must end up in the live content tree.
      _contentOpacityLayer.layer = context.pushOpacity(
        offset,
        ui.Color.getAlphaFromOpacity(blendValue!),
        (childContext, _) => super.paint(childContext, Offset.zero),
        oldLayer: _contentOpacityLayer.layer,
      );
      _skeletonOpacityLayer.layer = context.pushOpacity(
        Offset.zero,
        ui.Color.getAlphaFromOpacity(1 - blendValue),
        (childContext, _) => childContext.addLayer(cacheLayer),
        oldLayer: _skeletonOpacityLayer.layer,
      );
    }
  }

  @override
  OffsetLayer updateCompositedLayer({required OffsetLayer? oldLayer}) {
    final updatedLayer = super.updateCompositedLayer(oldLayer: oldLayer);
    final blendValue = _blend?.value;
    if (blendValue != null) {
      _contentOpacityLayer.layer?.alpha = ui.Color.getAlphaFromOpacity(blendValue);
      _skeletonOpacityLayer.layer?.alpha = ui.Color.getAlphaFromOpacity(1 - blendValue);
    }
    if (_effectNeedsUpdate && !_cacheNeedsUpdate && _boneSegments.isNotEmpty) {
      final effectT = _effectAnimationValue();
      _updateRetainedEffect(
        _buildSkeletonPaint(Offset.zero & size, t: effectT),
      );
    }
    return updatedLayer;
  }

  void _handleEffectTick() {
    _effectNeedsUpdate = true;
    if (!attached || _cacheNeedsUpdate || _boneSegments.isEmpty) {
      markNeedsCompositedLayerUpdate();
      return;
    }

    // The shared ticker has already scheduled this frame. Updating retained
    // layer properties here avoids queuing every Skeleton as a paint node.
    final effectT = _effectAnimationValue();
    _updateRetainedEffect(
      _buildSkeletonPaint(Offset.zero & size, t: effectT),
    );
  }

  void _syncClockRegistration() {
    if (!attached || !_animate) {
      _stopClockListening();
      return;
    }
    _SkeletonAnimationClock.instance.addListener(
      _handleEffectTick,
      forceFrames: _forceFrames,
    );
    _clockListening = true;
  }

  void _stopClockListening() {
    if (!_clockListening) return;
    _SkeletonAnimationClock.instance.removeListener(_handleEffectTick);
    _clockListening = false;
  }

  void _updateRetainedEffect(Paint skeletonPaint) {
    if (_style.effect is SkeletonShimmerEffect) {
      final rootBounds = Offset.zero & size;
      for (final segment in _boneSegments) {
        final segmentOrigin = segment.bounds.topLeft;
        final alignedPaint = segmentOrigin == Offset.zero
            ? skeletonPaint
            : _buildSkeletonPaint(
                rootBounds.shift(-segmentOrigin),
                t: _effectAnimationValue(),
              );
        segment.update(alignedPaint, _style);
      }
      _effectNeedsUpdate = false;
      return;
    }

    for (final segment in _boneSegments) {
      segment.update(skeletonPaint, _style);
    }
    _effectNeedsUpdate = false;
  }

  double _effectAnimationValue() {
    final effect = _style.effect;
    if (effect is! SkeletonAnimatedEffectBase) return 0;
    if (!_animate) {
      // Keep an outgoing animated skeleton at its last visible phase.
      return _blend != null && !_enabled && _blend!.value < 1 ? _lastEffectAnimationValue : 0;
    }
    return _lastEffectAnimationValue = _SkeletonEffectFrameCache.instance.animationValue(
      effect,
      _SkeletonAnimationClock.instance.elapsed,
    );
  }

  Paint _buildSkeletonPaint(Rect bounds, {required double t}) {
    final effect = _style.effect;
    if (effect == null) return _solidSkeletonPaint;

    if (effect.runtimeType == SkeletonFadeEffect || effect.runtimeType == SkeletonShimmerEffect) {
      if (!_animate) {
        return effect.buildPaint(bounds: bounds, t: t, style: _style);
      }
      return _SkeletonEffectFrameCache.instance.builtInPaint(
        effect: effect,
        bounds: bounds,
        t: t,
        style: _style,
      );
    }
    return effect.buildPaint(bounds: bounds, t: t, style: _style);
  }

  _SkeletonBoneSegmentMode _segmentModeFor(SkeletonEffect? effect) {
    if (effect is SkeletonFadeEffect) return _SkeletonBoneSegmentMode.fade;
    if (effect is SkeletonShimmerEffect) {
      return _SkeletonBoneSegmentMode.shimmerMask;
    }
    if (effect is SkeletonAnimatedEffectBase) {
      return _SkeletonBoneSegmentMode.customAnimated;
    }
    return _SkeletonBoneSegmentMode.staticPicture;
  }

  @override
  void dispose() {
    _blend?.removeListener(_onBlendChanged);
    _stopClockListening();
    _contentOpacityLayer.layer = null;
    _skeletonOpacityLayer.layer = null;
    _cacheLayer.layer = null;
    _boneSegments.clear();
    super.dispose();
  }
}
