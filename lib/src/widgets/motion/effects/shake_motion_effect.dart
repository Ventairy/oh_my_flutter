part of '../motion.dart';

/// Shakes a child along [offset] before returning it to its layout position.
///
/// Each [count] adds one excursion in the opposite direction from the
/// previous one. Positive offset coordinates determine the first direction,
/// while negative coordinates reverse it. Translation happens during
/// painting, so it does not change surrounding layout, and hit testing follows
/// the translated child.
class ShakeMotionEffect extends MotionEffect {
  /// Creates an effect that shakes along [offset].
  const ShakeMotionEffect({
    required this.offset,
    this.count = 3,
    this.damping = 1,
    super.delay = Duration.zero,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.linear,
    super.playback = MotionPlayback.once,
    super.onStart,
    super.onEnd,
  }) : assert(count > 0, 'count must be positive.'),
       assert(
         damping >= 0 && damping <= 1,
         'damping must be finite and between zero and one.',
       );

  /// Direction and logical-pixel strength of the shake.
  ///
  /// Use one non-zero coordinate for a horizontal or vertical shake, or both
  /// coordinates for a diagonal shake. The effect always starts and finishes
  /// at the child's layout position.
  final Offset offset;

  /// Number of alternating excursions completed during one playback.
  ///
  /// This defaults to three and must be positive.
  final int count;

  /// How strongly successive excursions lose displacement.
  ///
  /// A value of zero keeps the requested strength throughout playback. A
  /// value of one linearly reduces it toward rest. Intermediate values apply
  /// partial damping. This defaults to one and must be between zero and one,
  /// inclusive.
  final double damping;

  @override
  MotionEffectBounds get bounds {
    final absoluteOffset = Offset(offset.dx.abs(), offset.dy.abs());

    return MotionEffectBounds(
      minimumOffset: -absoluteOffset,
      maximumOffset: absoluteOffset,
    );
  }

  @override
  void apply(double progress, MotionEffectTransform transform) {
    final displacement = math.sin(progress * math.pi * count) * (1 - damping * progress);
    transform.translate(
      x: offset.dx * displacement,
      y: offset.dy * displacement,
    );
  }
}
