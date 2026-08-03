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
  Widget buildTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return _AnimatedMotionTranslation.floating(
      animation: animation,
      distance: distance,
      child: child,
    );
  }
}
