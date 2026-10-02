part of '../motion.dart';

/// Precomputes one effect's animation timeline and paint bounds.
class _MotionRenderEffect {
  new _({
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

  factory forMotion(_MotionApplication application) {
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

  factory forText(
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

  late final MotionEffectBounds bounds;

  double _nextCharacterProgress = 0;

  bool _frameIsDismissed = true;

  static MotionEffectBounds _sampleBounds(
    MotionEffect effect, {
    required bool isLinear,
  }) {
    final transform = MotionEffectTransform._();
    var minimumTranslationX = 0.0;
    var minimumTranslationY = 0.0;
    var maximumTranslationX = 0.0;
    var maximumTranslationY = 0.0;
    var maximumScale = 1.0;
    var maximumRotationDegrees = 0.0;
    for (var index = 0; index <= _boundsSampleCount; index += 1) {
      final timelineProgress = index / _boundsSampleCount;
      final progress = isLinear ? timelineProgress : effect.curve.transform(timelineProgress);
      transform._reset();
      effect.apply(progress, transform);
      minimumTranslationX = math.min(minimumTranslationX, transform._translationX);
      minimumTranslationY = math.min(minimumTranslationY, transform._translationY);
      maximumTranslationX = math.max(maximumTranslationX, transform._translationX);
      maximumTranslationY = math.max(maximumTranslationY, transform._translationY);
      maximumScale = math.max(maximumScale, transform._scale.abs());
      maximumRotationDegrees = math.max(maximumRotationDegrees, transform._rotationDegrees.abs());
    }
    final sampledBounds = MotionEffectBounds(
      minimumOffset: Offset(minimumTranslationX, minimumTranslationY),
      maximumOffset: Offset(maximumTranslationX, maximumTranslationY),
      maximumScale: maximumScale,
      maximumRotationDegrees: maximumRotationDegrees,
    );
    final declaredBounds = effect.bounds;
    if (declaredBounds == null) {
      return sampledBounds;
    }
    return MotionEffectBounds(
      minimumOffset: Offset(
        math.min(
          sampledBounds.minimumOffset.dx,
          declaredBounds.minimumOffset.dx,
        ),
        math.min(
          sampledBounds.minimumOffset.dy,
          declaredBounds.minimumOffset.dy,
        ),
      ),
      maximumOffset: Offset(
        math.max(
          sampledBounds.maximumOffset.dx,
          declaredBounds.maximumOffset.dx,
        ),
        math.max(
          sampledBounds.maximumOffset.dy,
          declaredBounds.maximumOffset.dy,
        ),
      ),
      maximumScale: math.max(
        sampledBounds.maximumScale,
        declaredBounds.maximumScale,
      ),
      maximumRotationDegrees: math.max(
        sampledBounds.maximumRotationDegrees,
        declaredBounds.maximumRotationDegrees,
      ),
    );
  }

  static Rect paintBoundsFor(Size size, List<_MotionRenderEffect> effects) {
    var maximumScale = 1.0;
    var horizontalMotion = 0.0;
    var verticalMotion = 0.0;
    var maximumRotationDegrees = 0.0;
    for (final effect in effects) {
      final bounds = effect.bounds;
      horizontalMotion += bounds._maximumAbsoluteTranslationX;
      verticalMotion += bounds._maximumAbsoluteTranslationY;
      maximumScale *= math.max(1, bounds.maximumScale);
      maximumRotationDegrees += bounds.maximumRotationDegrees;
    }
    if (maximumRotationDegrees > 0) {
      final halfWidth = size.width / 2;
      final halfHeight = size.height / 2;
      final radius = math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight);
      final radians = math.min(maximumRotationDegrees, 90) * math.pi / 180;
      final cosine = math.cos(radians);
      final sine = math.sin(radians);
      final horizontalRadius = radians >= math.atan2(halfHeight, halfWidth)
          ? radius
          : cosine * halfWidth + sine * halfHeight;
      final verticalRadius = radians >= math.atan2(halfWidth, halfHeight)
          ? radius
          : cosine * halfHeight + sine * halfWidth;
      final horizontalOutset = (horizontalRadius + horizontalMotion + sine * verticalMotion) * maximumScale - halfWidth;
      final verticalOutset = (verticalRadius + verticalMotion + sine * horizontalMotion) * maximumScale - halfHeight;
      return Rect.fromLTRB(
        -horizontalOutset,
        -verticalOutset,
        size.width + horizontalOutset,
        size.height + verticalOutset,
      );
    }
    final horizontalOutset = horizontalMotion * maximumScale + size.width * (maximumScale - 1) / 2;
    final verticalOutset = verticalMotion * maximumScale + size.height * (maximumScale - 1) / 2;
    return Rect.fromLTRB(
      -horizontalOutset,
      -verticalOutset,
      size.width + horizontalOutset,
      size.height + verticalOutset,
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
