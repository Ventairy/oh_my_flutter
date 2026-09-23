part of 'morph.dart';

final class _MorphNavigationRequest {
  new({
    required this.source,
    required this.destination,
    required this.kind,
    required this.operation,
    required this.revision,
    this.preview = false,
  });

  final Route<Object?>? source;
  final Route<Object?> destination;
  final MorphFlightKind kind;
  final MorphMatchOperation operation;
  final Map<(_MorphEndpointHandle, _MorphEndpointHandle, MorphTarget), bool> matchDecisions = {};
  final Map<_MorphEndpointHandle, MorphTarget> acceptedTargets = {};
  void forgetEndpoint(_MorphEndpointHandle endpoint) {
    acceptedTargets.remove(endpoint);
    matchDecisions.removeWhere((pair, _) => identical(pair.$1, endpoint) || identical(pair.$2, endpoint));
  }

  int revision;
  bool preview;
  bool cancelled = false;
}
