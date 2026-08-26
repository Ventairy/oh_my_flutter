part of 'skeleton.dart';

/// A skeleton effect that repeats over an animation interval.
abstract class SkeletonAnimatedEffectBase extends SkeletonEffect {
  /// Creates an animated skeleton effect.
  const SkeletonAnimatedEffectBase();

  /// The duration of one animation cycle.
  Duration get duration => const Duration(milliseconds: 1500);

  /// The first animation value passed to [buildPaint].
  double get lowerBound => -0.5;

  /// The last animation value passed to [buildPaint].
  double get upperBound => 1.5;
}
