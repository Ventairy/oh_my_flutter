part of 'skeleton.dart';

/// A gentle opacity cycle applied to skeleton bones.
@immutable
final class SkeletonFadeEffect extends SkeletonAnimatedEffectBase {
  /// Creates a repeating fade effect.
  const SkeletonFadeEffect({
    this.duration = const Duration(milliseconds: 1000),
    this.opacity = const (start: 0.4, end: 1),
  });

  /// The duration of one fade-in and fade-out cycle.
  @override
  final Duration duration;

  /// The opacity values used at the dimmest and brightest points.
  final ({double start, double end}) opacity;

  @override
  double get lowerBound => 0;

  @override
  double get upperBound => math.pi * 2;

  @override
  Paint buildPaint({
    required Rect bounds,
    required double t,
    required SkeletonStyle style,
  }) {
    final phase = (1 - math.cos(t)) / 2;
    final fadeAlpha = (opacity.start + (opacity.end - opacity.start) * phase).clamp(0.0, 1.0);
    return Paint()..color = style.color.withValues(alpha: style.color.a * fadeAlpha);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SkeletonFadeEffect && other.duration == duration && other.opacity == opacity;
  }

  @override
  int get hashCode => Object.hash(duration, opacity);
}
