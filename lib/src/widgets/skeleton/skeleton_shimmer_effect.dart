part of 'skeleton.dart';

/// A highlight band that repeatedly sweeps across skeleton bones.
@immutable
final class SkeletonShimmerEffect extends SkeletonAnimatedEffectBase {
  /// Creates a shimmer effect with a neutral light-gray highlight.
  const SkeletonShimmerEffect({
    this.color = const Color(0xFFF5F5F5),
    this.angle = 0,
    this.duration = const Duration(milliseconds: 1500),
  });

  /// The highlight color at the center of the shimmer band.
  final Color color;

  /// The sweep angle in radians.
  final double angle;

  /// The duration of one shimmer sweep.
  @override
  final Duration duration;

  @override
  Paint buildPaint({
    required Rect bounds,
    required double t,
    required SkeletonStyle style,
  }) {
    final center = bounds.center;
    final isHorizontal = angle == 0;
    final dx = isHorizontal ? 1.0 : math.cos(angle);
    final dy = isHorizontal ? 0.0 : math.sin(angle);
    final halfLength = (dx * bounds.width / 2).abs() + (dy * bounds.height / 2).abs();
    final travel = halfLength * 2;
    final shift = Offset(dx * travel * t, dy * travel * t);
    final start = center - Offset(dx * halfLength, dy * halfLength) + shift;
    final end = center + Offset(dx * halfLength, dy * halfLength) + shift;

    return Paint()
      ..shader = ui.Gradient.linear(
        start,
        end,
        <Color>[style.color, color, style.color],
        const <double>[0.1, 0.3, 0.4],
        TileMode.clamp,
      );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SkeletonShimmerEffect && other.color == color && other.angle == angle && other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(color, angle, duration);
}
