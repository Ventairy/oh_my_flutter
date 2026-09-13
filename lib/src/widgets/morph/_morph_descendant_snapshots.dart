part of 'morph.dart';

final class _MorphDescendantSnapshots {
  const _MorphDescendantSnapshots._();

  static final Expando<Set<_MorphDescendantCapture>> _captures = Expando<Set<_MorphDescendantCapture>>(
    'oh_my_flutter.morph.registeredDescendants',
  );
  static void attach(
    MorphEndpoint<Object?> endpoint, {
    required _MorphDescendantCapture capture,
  }) {
    _captures[endpoint] = {capture};
  }

  static Set<_MorphDescendantCapture> capturesOf(MorphEndpoint<Object?> endpoint) {
    return _captures[endpoint] ?? const {};
  }

  static _MorphDescendantCapture? captureOf(MorphEndpoint<Object?> endpoint) {
    return capturesOf(endpoint).singleOrNull;
  }

  static T copy<T extends MorphEndpoint<Object?>>(MorphEndpoint<Object?> source, T destination) {
    _captures[destination] = _captures[source];
    return destination;
  }

  static T combine<T extends MorphEndpoint<Object?>>(
    MorphEndpoint<Object?> source,
    MorphEndpoint<Object?> destination,
    T sample,
  ) {
    final captures = switch (sample.properties) {
      final _MorphAutomaticProperties properties => properties.descendantCaptures,
      _ => {...capturesOf(source), ...capturesOf(destination)},
    };
    if (captures.isNotEmpty) _captures[sample] = captures;
    return sample;
  }
}
