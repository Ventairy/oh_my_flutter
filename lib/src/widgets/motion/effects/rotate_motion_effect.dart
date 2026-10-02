part of '../motion.dart';

/// Rotates a child clockwise or counterclockwise from its current orientation.
///
/// Rotation happens around the child's center without changing its layout.
/// Positive [degrees] turn clockwise on screen; negative values turn
/// counterclockwise. The same effect rotates each visible grapheme separately
/// in [TextMotion].
///
/// See the [Motion guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/motion.md)
/// for combining rotation with other effects and controlling playback.
class RotateMotionEffect extends MotionEffect {
  /// Creates an effect that rotates from zero to [degrees].
  const new({
    required this.degrees,
    super.delay = Duration.zero,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.linear,
    super.playback = MotionPlayback.once,
    super.onStart,
    super.onEnd,
  }) : assert(
         degrees > double.negativeInfinity && degrees < double.infinity,
         'degrees must be finite.',
       );

  /// Relative angle reached at animation progress `1`, in degrees.
  final double degrees;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.rotate(degrees * progress);
  }
}
