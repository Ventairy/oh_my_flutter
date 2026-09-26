part of '../motion.dart';

/// Gently dims a widget or text and restores its full visibility in a loop.
///
/// The child starts fully visible, reaches [minOpacity] halfway through each
/// cycle, and returns to full opacity. Reduced motion keeps it fully visible.
class PulseFadeMotionEffect extends MotionEffect {
  /// Creates a continuously breathing fade.
  const new({
    this.minOpacity = 0.5,
    super.delay = Duration.zero,
    super.duration = const Duration(seconds: 2),
    super.curve = Curves.linear,
    super.onStart,
  }) : assert(
         minOpacity >= 0 && minOpacity <= 1,
         'minOpacity must be between zero and one.',
       ),
       super(playback: MotionPlayback.loop);

  /// Lowest opacity reached during each cycle, from zero to one inclusive.
  final double minOpacity;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    final wave = (1 + math.cos(2 * math.pi * progress)) / 2;
    transform.fade(minOpacity + (1 - minOpacity) * wave);
  }
}
