part of 'morph.dart';

/// Chooses how a shared element appears while moving between matching widgets.
///
/// Set [Morph.flightConfig] to configure the visual shown during a transition.
/// The departing endpoint supplies the configuration for that direction.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md)
/// for automatic and custom transitions.
sealed class MorphFlightConfig {
  const MorphFlightConfig._();

  /// Animates supported widgets automatically and configures child replacement.
  ///
  /// [childSwitchAt] is the curved flight progress at which source content is
  /// replaced by destination content. It defaults to 0.5 and must be between
  /// 0 and 1, inclusive. It is not a fraction of elapsed time unless the flight
  /// uses a linear curve.
  ///
  /// [childTransition] can animate changing text, generic children, and ordinary
  /// content inside supported widgets. Its animation moves from 1 to 0 for
  /// departing content and from 0 to 1 for arriving content. When omitted,
  /// content switches immediately. Nested Morphs animate independently.
  const factory MorphFlightConfig.auto({
    double childSwitchAt,
    Widget Function(Widget child, Animation<double> animation)? childTransition,
  }) = _MorphAutoFlightConfiguration;

  /// Uses [delegate] to capture, interpolate, and build the shared visual.
  ///
  /// Use the same delegate runtime type and the same endpoint property type at
  /// both endpoints. The departing delegate controls the transition, including
  /// any child replacement effects.
  const factory MorphFlightConfig.custom(
    MorphFlightDelegate<Object?> delegate,
  ) = _MorphCustomFlightConfiguration;
}
