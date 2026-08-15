import 'dart:convert';

/// Buffers benchmark records until timed work has finished.
final class MorphBenchmarkRecordBuffer {
  /// Creates a benchmark record buffer that writes complete log lines with
  /// the supplied emitter.
  MorphBenchmarkRecordBuffer(this._emit);

  static const String _recordMarker = 'MORPH_BENCHMARK ';

  final void Function(String message) _emit;
  final List<Map<String, Object>> _records = <Map<String, Object>>[];

  /// Number of records waiting to be emitted.
  int get pendingCount => _records.length;

  /// Adds [record] without serializing or emitting it.
  void add(Map<String, Object> record) {
    _records.add(Map<String, Object>.unmodifiable(record));
  }

  /// Emits all pending records in insertion order and clears the buffer.
  void flush() {
    if (_records.isEmpty) return;
    final records = List<Map<String, Object>>.of(_records, growable: false);
    _records.clear();
    for (final record in records) {
      _emit('$_recordMarker${jsonEncode(record)}');
    }
  }
}
