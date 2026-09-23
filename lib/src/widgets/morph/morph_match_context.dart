part of 'morph.dart';

/// Describes the appearances being considered for a shared flight.
///
/// Use the route identities and operation to restrict matching in
/// [MorphTarget.canMatch]. Approval does not guarantee that a flight can start.
@immutable
final class MorphMatchContext {
  /// Creates the context for a proposed match.
  const new({required this.sourceRoute, required this.destinationRoute, required this.operation});

  /// The route containing the departing appearance, or null outside a route.
  final Route<Object?>? sourceRoute;

  /// The route containing the arriving appearance, or null outside a route.
  ///
  /// Local matches have the same route on both sides, possibly null.
  final Route<Object?>? destinationRoute;

  /// The observed operation that brought these appearances together.
  final MorphMatchOperation operation;
}
