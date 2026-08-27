part of 'skeleton.dart';

// Built-in animated effects in a list normally have identical phase, bounds,
// and colors. Sharing their immutable Paint/Shader for the duration of a frame
// avoids rebuilding the same native gradient once per Skeleton instance.
class _SkeletonEffectFrameCache {
  _SkeletonEffectFrameCache._();

  static final _SkeletonEffectFrameCache instance = _SkeletonEffectFrameCache._();

  final Map<SkeletonAnimatedEffectBase, double> _animationValues = <SkeletonAnimatedEffectBase, double>{};
  final Map<_SkeletonBuiltInPaintKey, Paint> _paints = <_SkeletonBuiltInPaintKey, Paint>{};

  void clear() {
    _animationValues.clear();
    _paints.clear();
  }

  void beginFrame() => clear();

  double animationValue(
    SkeletonAnimatedEffectBase effect,
    Duration elapsed,
  ) {
    return _animationValues.putIfAbsent(effect, () {
      final durationMicros = effect.duration.inMicroseconds;
      if (durationMicros <= 0) return effect.lowerBound;
      final phase = (elapsed.inMicroseconds % durationMicros) / durationMicros;
      return effect.lowerBound + (effect.upperBound - effect.lowerBound) * phase;
    });
  }

  Paint builtInPaint({
    required SkeletonEffect effect,
    required Rect bounds,
    required double t,
    required SkeletonStyle style,
  }) {
    final key = _SkeletonBuiltInPaintKey(
      effect: effect,
      bounds: bounds,
      color: style.color,
      t: t,
    );
    return _paints.putIfAbsent(
      key,
      () => effect.buildPaint(bounds: bounds, t: t, style: style),
    );
  }
}
