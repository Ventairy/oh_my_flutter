part of '../motion.dart';

/// Fades a child from transparent to fully opaque.
///
/// The effect uses [FadeTransition], so animation frames update opacity without
/// rebuilding the child subtree.
class FadeInMotionEffect extends MotionEffect {
  /// Creates a fade-in effect.
  const FadeInMotionEffect({
    super.delay = Duration.zero,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.linear,
    super.playback = MotionPlayback.once,
    super.onStart,
    super.onEnd,
  });

  @override
  Widget buildTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}
