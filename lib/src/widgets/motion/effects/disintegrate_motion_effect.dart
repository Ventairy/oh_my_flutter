part of '../motion.dart';

/// Breaks content into rounded particles that shrink and fade away.
///
/// Use [direction] to make the pieces drift, or [Offset.zero] to keep them in
/// place. Combine this effect with other effects or call
/// [MotionEffectTransform.disintegrate] from a custom [MotionEffect].
class DisintegrateMotionEffect extends MotionEffect {
  /// Creates a disintegration with optional directional movement.
  const new({
    required this.direction,
    super.delay,
    super.duration,
    super.curve,
    super.playback,
    super.onStart,
    super.onEnd,
  });

  /// Travel direction. Magnitude is ignored; zero keeps every piece in place.
  final Offset direction;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.disintegrate(progress: progress, direction: direction);
  }
}
