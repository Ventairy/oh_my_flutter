part of '../motion.dart';

/// Precomputes one effect's animation timeline and paint bounds.
class _MotionRenderEffect {
  _MotionRenderEffect._({
    required this.animation,
    required this.effect,
    required this.usesTextTimeline,
    required this.loops,
    required this.staggerMicroseconds,
    required this.timelineMicroseconds,
    required this.effectMicroseconds,
  }) : startProgress = effect.curve.transform(0),
       endProgress = effect.curve.transform(1),
       characterProgressStep =
           (loops ? staggerMicroseconds % effectMicroseconds : staggerMicroseconds) / effectMicroseconds,
       timelineToEffectRatio = timelineMicroseconds / effectMicroseconds,
       isLinear = identical(effect.curve, Curves.linear) {
    bounds = _sampleBounds(effect, isLinear: isLinear);
  }

  factory _MotionRenderEffect.forMotion(_MotionApplication application) {
    final effect = application.effect;
    return _MotionRenderEffect._(
      animation: application.animation,
      effect: effect,
      usesTextTimeline: false,
      loops: !effect.playback.isOnce,
      staggerMicroseconds: 0,
      timelineMicroseconds: effect.duration.inMicroseconds,
      effectMicroseconds: effect.duration.inMicroseconds,
    );
  }

  factory _MotionRenderEffect.forText(
    _TextMotionApplication application,
  ) {
    final effect = application.effect;
    return _MotionRenderEffect._(
      animation: application.animation,
      effect: effect,
      usesTextTimeline: true,
      loops: !effect.playback.isOnce,
      staggerMicroseconds: application.stagger.inMicroseconds,
      timelineMicroseconds: application.timelineDuration.inMicroseconds,
      effectMicroseconds: effect.duration.inMicroseconds,
    );
  }

  static const int _boundsSampleCount = 64;

  final Animation<double> animation;

  final MotionEffect effect;

  final bool usesTextTimeline;

  final bool loops;

  final int staggerMicroseconds;

  final int timelineMicroseconds;

  final int effectMicroseconds;

  final double startProgress;

  final double endProgress;

  final double characterProgressStep;

  final double timelineToEffectRatio;

  final bool isLinear;

  late final _MotionEffectBounds bounds;

  double _nextCharacterProgress = 0;

  bool _frameIsDismissed = true;

  static _MotionEffectBounds _sampleBounds(
    MotionEffect effect, {
    required bool isLinear,
  }) {
    final transform = MotionEffectTransform._();
    var maximumTranslationX = 0.0;
    var maximumTranslationY = 0.0;
    var maximumScale = 1.0;
    for (var index = 0; index <= _boundsSampleCount; index += 1) {
      final timelineProgress = index / _boundsSampleCount;
      final progress = isLinear ? timelineProgress : effect.curve.transform(timelineProgress);
      transform._reset();
      effect.apply(progress, transform);
      maximumTranslationX = math.max(
        maximumTranslationX,
        transform._translationX.abs(),
      );
      maximumTranslationY = math.max(
        maximumTranslationY,
        transform._translationY.abs(),
      );
      maximumScale = math.max(maximumScale, transform._scale.abs());
    }
    return _MotionEffectBounds(
      maximumAbsoluteTranslationX: maximumTranslationX,
      maximumAbsoluteTranslationY: maximumTranslationY,
      maximumAbsoluteScale: maximumScale,
    );
  }

  void prepareFrame() {
    if (!usesTextTimeline) {
      _nextCharacterProgress = animation.value;
      return;
    }
    _frameIsDismissed = animation.status.isDismissed;
    if (_frameIsDismissed) {
      return;
    }
    if (loops) {
      final progress = animation.value;
      _nextCharacterProgress = progress >= 1 ? 0 : progress;
      return;
    }
    _nextCharacterProgress = animation.value * timelineToEffectRatio;
  }

  double nextProgress() {
    if (!usesTextTimeline) {
      return _nextCharacterProgress;
    }
    if (_frameIsDismissed) {
      return startProgress;
    }

    final progress = _nextCharacterProgress;
    _nextCharacterProgress -= characterProgressStep;
    if (loops) {
      if (_nextCharacterProgress < 0) {
        _nextCharacterProgress += 1;
      }
      return isLinear ? progress : effect.curve.transform(progress);
    }
    if (progress <= precisionErrorTolerance) {
      return startProgress;
    }
    if (progress >= 1 - precisionErrorTolerance) {
      return endProgress;
    }
    return isLinear ? progress : effect.curve.transform(progress);
  }
}
