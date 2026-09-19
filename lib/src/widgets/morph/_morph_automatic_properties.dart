part of 'morph.dart';

@immutable
final class _MorphAutomaticProperties {
  const new(this.child);

  final MorphChildProperties child;

  Set<_MorphDescendantCapture> get descendantCaptures {
    final captures = <_MorphDescendantCapture>{};
    _collectDescendantCaptures(child, captures);
    return captures;
  }

  static void _collectDescendantCaptures(
    MorphChildProperties properties,
    Set<_MorphDescendantCapture> captures,
  ) {
    if (properties.widget case _MorphRegisteredDescendant(:final capture)) {
      captures.add(capture);
    }
    final containerChild = properties.container?.child;
    if (containerChild != null) _collectDescendantCaptures(containerChild, captures);
    final column = properties.column;
    if (column != null) {
      for (final child in column.children) {
        _collectDescendantCaptures(child, captures);
      }
    }
  }
}
