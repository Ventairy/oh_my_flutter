part of 'morph.dart';

final class _MorphNavigationRequest {
  new({
    required this.source,
    required this.destination,
    required this.kind,
    required this.revision,
    this.preview = false,
  });

  final Route<Object?>? source;
  final Route<Object?> destination;
  final MorphFlightKind kind;
  int revision;
  bool preview;
  bool cancelled = false;
}
