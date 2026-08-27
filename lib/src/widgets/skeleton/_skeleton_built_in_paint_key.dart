part of 'skeleton.dart';

@immutable
class _SkeletonBuiltInPaintKey {
  const _SkeletonBuiltInPaintKey({
    required this.effect,
    required this.bounds,
    required this.color,
    required this.t,
  });

  final SkeletonEffect effect;
  final Rect bounds;
  final Color color;
  final double t;

  @override
  bool operator ==(Object other) {
    return other is _SkeletonBuiltInPaintKey &&
        other.effect == effect &&
        other.bounds == bounds &&
        other.color == color &&
        other.t == t;
  }

  @override
  int get hashCode => Object.hash(effect, bounds, color, t);
}
