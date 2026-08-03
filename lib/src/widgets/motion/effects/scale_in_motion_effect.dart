part of '../motion.dart';

/// Scales a child from [scale] to its normal size.
///
/// Scaling happens during painting and does not affect surrounding layout.
/// Animation frames update the render transform directly without rebuilding
/// either the transition widget or the child subtree.
class ScaleInMotionEffect extends MotionEffect {
  /// Creates an effect that scales from [scale] to `1.0`.
  const ScaleInMotionEffect({
    this.scale = 0,
    super.delay = Duration.zero,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.linear,
    super.playback = MotionPlayback.once,
    super.onStart,
    super.onEnd,
  });

  /// Scale applied at animation progress `0`.
  ///
  /// The effect always finishes at the child's normal `1.0` scale.
  final double scale;

  @override
  Widget buildTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return _AnimatedMotionScale(
      animation: animation,
      beginScale: scale,
      child: child,
    );
  }
}
