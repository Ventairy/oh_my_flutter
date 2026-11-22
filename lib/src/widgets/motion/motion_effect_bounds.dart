part of 'motion.dart';

/// Declares a visual range that Motion must keep available for a [MotionEffect].
///
/// Custom effects must provide bounds when oscillating, abrupt, or short-lived
/// transformations can reach extremes that would otherwise be clipped.
/// Declaring bounds does not restrict the effect from moving beyond them.
@immutable
final class MotionEffectBounds {
  /// Creates bounds for an effect's translation, scale, rotation, and blur range.
  const new({
    this.minimumOffset = Offset.zero,
    this.maximumOffset = Offset.zero,
    this.maximumScale = 1,
    this.maximumRotationDegrees = 0,
    this.maximumBlurSigma = 0,
  }) : assert(
         maximumScale >= 0 && maximumScale < double.infinity,
         'maximumScale must be finite and non-negative.',
       ),
       assert(
         maximumRotationDegrees >= 0 && maximumRotationDegrees < double.infinity,
         'maximumRotationDegrees must be finite and non-negative.',
       ),
       assert(
         maximumBlurSigma >= 0 && maximumBlurSigma < double.infinity,
         'maximumBlurSigma must be finite and non-negative.',
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

  /// Largest absolute angle, in degrees, reached by this effect.
  ///
  /// Set this when a brief or abrupt rotation could be missed during bounds
  /// sampling. It reserves room for rotated content without changing playback.
  final double maximumRotationDegrees;

  /// Largest blur sigma, in logical pixels, reached by this effect.
  ///
  /// Set this to reserve room for a brief blur peak that could be missed
  /// during bounds sampling. It defaults to zero and does not cap the blur.
  final double maximumBlurSigma;

  double get _maximumAbsoluteTranslationX => math.max(
    minimumOffset.dx.abs(),
    maximumOffset.dx.abs(),
  );

  double get _maximumAbsoluteTranslationY => math.max(
    minimumOffset.dy.abs(),
    maximumOffset.dy.abs(),
  );
}
