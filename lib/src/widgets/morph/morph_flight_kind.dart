/// Describes what caused a Morph transition.
enum MorphFlightKind {
  /// The shared element moved within the current screen.
  sameScreen,

  /// The shared element is moving into a newly opened route.
  routePush,

  /// The shared element is returning as the current route closes.
  routePop;

  /// Whether the transition is part of a Navigator route change.
  bool get isRoute => switch (this) {
    MorphFlightKind.sameScreen => false,
    MorphFlightKind.routePush || MorphFlightKind.routePop => true,
  };
}
