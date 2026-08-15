part of 'morph.dart';

final class _MorphRasterSnapshotRetry<K> {
  _MorphRasterSnapshotRetry({
    required this.key,
    required this.generation,
  });

  final K key;
  final int generation;
  final Completer<bool> completer = Completer<bool>();
  int waiters = 0;
}
