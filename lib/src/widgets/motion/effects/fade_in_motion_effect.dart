part of '../motion.dart';

/// Fades a child from transparent to fully opaque.
class FadeInMotionEffect extends MotionEffect {
  /// Creates a fade-in effect.
  const new({
    super.delay = Duration.zero,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.linear,
    super.playback = MotionPlayback.once,
    super.onStart,
    super.onEnd,
  });

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.fade(progress);
  }
}
