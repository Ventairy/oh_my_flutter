part of '../motion.dart';

/// Reveals a child by scaling it to normal size while fading it in.
///
/// Use this entrance for content such as a newly shown icon or message. The
/// child starts transparent at [scale] and finishes fully opaque at normal
/// size. Scaling does not affect surrounding layout. Both changes share the
/// configured [duration] and [curve]; choose an overshooting curve explicitly
/// when the child should grow past normal size before settling.
///
/// See the [Motion guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/motion.md)
/// for configuration, playback, and reduced-motion behavior.
class PopMotionEffect extends MotionEffect {
  /// Creates a scale-and-fade entrance from [scale] to normal size.
  const new({
    this.scale = 0.75,
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

  /// Starting size relative to the child's normal size.
  ///
  /// Defaults to `0.75` and must be finite. The effect always finishes at
  /// `1.0`. Use zero to grow from a point or one to fade without scaling.
  final double scale;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..scale(scale + (1 - scale) * progress)
      ..fade(progress);
  }
}
