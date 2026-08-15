part of 'motion.dart';

/// Declares a visual range that Motion must keep available for a [MotionEffect].
///
/// Custom effects must provide bounds when oscillating, abrupt, or short-lived
/// transformations can reach extremes that would otherwise be clipped.
/// Declaring bounds does not restrict the effect from moving beyond them.
@immutable
final class MotionEffectBounds {
  /// Creates bounds for an effect's translation and scale range.
  const MotionEffectBounds({
    this.minimumOffset = Offset.zero,
    this.maximumOffset = Offset.zero,
    this.maximumScale = 1,
  }) : assert(
         maximumScale >= 0 && maximumScale < double.infinity,
         'maximumScale must be finite and non-negative.',
       );

  /// Smallest horizontal and vertical offsets the effect can paint at.
  ///
  /// Each coordinate must be finite and no greater than the corresponding
  /// coordinate in [maximumOffset]. This defaults to [Offset.zero].
  final Offset minimumOffset;

  /// Largest horizontal and vertical offsets the effect can paint at.
  ///
  /// Each coordinate must be finite and no smaller than the corresponding
  /// coordinate in [minimumOffset]. This defaults to [Offset.zero].
  final Offset maximumOffset;

  /// Largest absolute scale the effect can paint at.
  ///
  /// This defaults to one and must be finite and non-negative. Values below
  /// one do not reduce the child's layout paint bounds.
  final double maximumScale;

  double get _maximumAbsoluteTranslationX => math.max(
    minimumOffset.dx.abs(),
    maximumOffset.dx.abs(),
  );

  double get _maximumAbsoluteTranslationY => math.max(
    minimumOffset.dy.abs(),
    maximumOffset.dy.abs(),
  );
}
