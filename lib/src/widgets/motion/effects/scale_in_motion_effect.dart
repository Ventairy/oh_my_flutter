part of '../motion.dart';

/// Scales a child from [scale] to its normal size.
///
/// Scaling does not affect surrounding layout.
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
  }) : assert(
         scale > double.negativeInfinity && scale < double.infinity,
         'scale must be finite.',
       );

  /// Scale applied at animation progress `0`.
  ///
  /// The effect always finishes at the child's normal `1.0` scale.
  final double scale;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.scale(scale + (1 - scale) * progress);
  }
}
