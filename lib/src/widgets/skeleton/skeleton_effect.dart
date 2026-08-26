part of 'skeleton.dart';

/// A reusable paint treatment for skeleton bones.
// Effects remain types so consumers can provide reusable paint behavior.
// ignore: one_member_abstracts
abstract class SkeletonEffect {
  /// Creates a skeleton paint effect.
  const SkeletonEffect();

  /// The paint used for the skeleton at animation value [t].
  Paint buildPaint({
    required Rect bounds,
    required double t,
    required SkeletonStyle style,
  });
}
