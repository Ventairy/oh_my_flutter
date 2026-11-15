part of '../motion.dart';

/// Breaks content into small pieces that shrink and fade away.
///
/// Use [direction] to make the pieces drift, or [Offset.zero] to keep them in
/// place. Combine this effect with other effects or call
/// [MotionEffectTransform.disintegrate] from a custom [MotionEffect].
class DisintegrateMotionEffect extends MotionEffect {
  /// Creates a disintegration with optional directional movement.
  const new({
    required this.direction,
    this.particleSize = MotionEffectTransform.defaultParticleSize,
    super.delay,
    super.duration,
    super.curve,
    super.playback,
    super.onStart,
    super.onEnd,
  }) : assert(particleSize > 0 && particleSize < double.infinity, 'particleSize must be positive and finite.');

  /// Travel direction. Magnitude is ignored; zero keeps every piece in place.
  final Offset direction;

  /// Desired piece size in logical source pixels, subject to the effect budget.
  ///
  /// Must be positive and finite. Keep this fixed throughout a playback run.
  final double particleSize;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.disintegrate(progress: progress, direction: direction, particleSize: particleSize);
  }
}
