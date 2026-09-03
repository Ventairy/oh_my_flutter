part of '../motion.dart';

/// Scales a child from its normal size to [scale].
///
/// Scaling does not affect surrounding layout.
///
/// See the [Motion guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/motion.md)
/// for combining scale with other effects and controlling playback.
class ScaleOutMotionEffect extends MotionEffect {
  /// Creates an effect that scales from `1.0` to [scale].
  const ScaleOutMotionEffect({
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

  /// Scale applied at animation progress `1`.
  ///
  /// The effect always starts at the child's normal `1.0` scale.
  final double scale;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.scale(1 + (scale - 1) * progress);
  }
}
