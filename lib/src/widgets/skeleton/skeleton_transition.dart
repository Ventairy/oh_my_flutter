part of 'skeleton.dart';

/// Animates a change between a loading skeleton and its content.
///
/// Choose [SkeletonTransition.crossfade] for a live blend or
/// [SkeletonTransition.custom] to compose Flutter transition widgets.
///
/// See the [Skeleton guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/skeleton.md)
/// for examples and usage guidance.
sealed class SkeletonTransition {
  const new _();

  /// Blends the skeleton and content while preserving the child's state.
  const factory crossfade({
    Duration duration,
    Curve curve,
  }) = _SkeletonCrossfadeTransition;

  /// Builds a custom transition between the outgoing and incoming visuals.
  ///
  /// [transitionBuilder] receives an animation from zero to one. Include the
  /// incoming visual exactly once in its result. Choose transition widgets
  /// that preserve the incoming child's interaction and accessibility when it
  /// becomes visible. The outgoing visual is a captured, noninteractive image,
  /// which remains still during the transition and costs memory proportional
  /// to the skeleton's painted size.
  const factory custom({
    required Widget Function(
      Widget outgoing,
      Widget incoming,
      Animation<double> animation,
    )
    transitionBuilder,
    Duration duration,
    Curve curve,
  }) = _SkeletonCustomTransition;

  /// Time taken to complete a switch in either direction.
  Duration get duration;

  /// Timing curve applied to the switch animation.
  Curve get curve;

  Widget Function(Widget, Widget, Animation<double>)? get _builder;

  bool _debugValidateDuration() {
    assert(!duration.isNegative, 'transition duration must not be negative.');
    return true;
  }
}
