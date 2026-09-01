part of 'interactive_swipe_dismiss.dart';

/// Configures how pointer travel moves and dismisses an
/// [InteractiveSwipeDismiss] child.
@immutable
final class InteractiveSwipeDismissDragConfig {
  /// Creates drag configuration for [InteractiveSwipeDismiss].
  const InteractiveSwipeDismissDragConfig({
    this.freeDrag = false,
    this.sensitivity = 1,
    this.dismissThreshold = 0.5,
  }) : assert(
         sensitivity > 0 && sensitivity < double.infinity,
         'sensitivity must be finite and greater than zero.',
       ),
       assert(
         dismissThreshold >= 0 && dismissThreshold <= 1,
         'dismissThreshold must be between zero and one, inclusive.',
       );

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

  /// The fraction of the matching viewport axis the finger must travel before
  /// release commits dismissal.
  ///
  /// This uses the unscaled finger distance, so [sensitivity] does not change
  /// how far the user must drag. The value is inclusive from `0` to `1`.
  final double dismissThreshold;
}
