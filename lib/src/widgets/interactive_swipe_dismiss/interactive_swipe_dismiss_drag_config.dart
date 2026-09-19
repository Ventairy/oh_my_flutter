part of 'interactive_swipe_dismiss.dart';

/// Configures how pointer travel moves and dismisses an
/// [InteractiveSwipeDismiss] child.
@immutable
final class InteractiveSwipeDismissDragConfig {
  /// Creates drag configuration for [InteractiveSwipeDismiss].
  const new({
    this.freeDrag = false,
    this.sensitivity = 1,
    this.dismissFraction = 0.5,
    this.returnCurve = Curves.linear,
    this.returnDuration = const Duration(milliseconds: 260),
  }) : assert(
         sensitivity > 0 && sensitivity < double.infinity,
         'sensitivity must be finite and greater than zero.',
       ),
       assert(
         dismissFraction >= 0 && dismissFraction <= 1,
         'dismissFraction must be between zero and one, inclusive.',
       );

  bool _debugValidate() {
    assert(!returnDuration.isNegative, 'returnDuration must be nonnegative.');
    return true;
  }

  /// The easing used when the child returns to its resting position.
  final Curve returnCurve;

  /// How long the child takes to return to its resting position.
  ///
  /// Must be nonnegative. Zero restores immediately, as does reduced motion.
  final Duration returnDuration;

  /// Whether the child follows pointer movement on both axes.
  ///
  /// When `false`, only movement toward the configured direction is shown.
  /// When `true`, the child follows the complete pointer offset after the
  /// directional dismissal gesture begins.
  final bool freeDrag;

  /// Multiplies the visual translation without changing dismissal distance.
  ///
  /// Values below `1` make the child travel less than the pointer, while values
  /// above `1` make it travel farther.
  final double sensitivity;

  /// The fraction of the child's size to drag before release
  /// commits dismissal, according to the dismissal direction.
  ///
  /// This uses the unscaled finger distance, so [sensitivity] does not change
  /// how far the user must drag. The size includes the wrapped child's padding
  /// and is captured when the gesture starts. The value is inclusive from
  /// `0` to `1`. A sufficiently fast fling can dismiss before this distance.
  /// Without a positive finite child size, only a fling can commit dismissal.
  final double dismissFraction;
}
