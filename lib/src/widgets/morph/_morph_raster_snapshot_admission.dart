part of 'morph.dart';

final class _MorphRasterSnapshotAdmission<K, V> {
  new({
    required this.key,
    required this.generation,
  });

  final K key;
  final int generation;
  final Completer<V> completer = Completer<V>();
}
