part of '../motion.dart';

/// Moves a child gently above and below its layout position.
///
/// The effect starts at rest, reaches [distance] logical pixels above its
/// layout position after one quarter-cycle, returns to rest halfway through,
/// moves the same distance below after three quarters, and finishes at rest.
/// Translation happens during painting, so it does not change surrounding
/// layout. Hit testing follows the translated child.
class FloatingMotionEffect extends MotionEffect {
  /// Creates a balanced vertical floating effect.
  const FloatingMotionEffect({
    this.distance = 8,
    super.delay = Duration.zero,
    super.duration = const Duration(milliseconds: 2400),
    super.curve = Curves.linear,
    super.onStart,
  }) : super(playback: MotionPlayback.loop);

  /// Maximum logical-pixel displacement above and below the layout position.
  final double distance;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.translate(x: 0, y: _translationFor(progress));
  }

  double _translationFor(double progress) {
    final amplitude = 16 * distance;
    return switch (progress) {
      0 || 0.5 || 1 => 0,
      < 0.5 => -amplitude * progress * (0.5 - progress),
      _ => amplitude * (progress - 0.5) * (1 - progress),
    };
  }
}
