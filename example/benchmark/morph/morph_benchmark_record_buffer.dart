import 'dart:convert';
import 'dart:math' as math;

/// Buffers benchmark records until timed work has finished.
final class MorphBenchmarkRecordBuffer {
  /// Creates a benchmark record buffer that writes complete log lines with
  /// the supplied emitter.
  MorphBenchmarkRecordBuffer(this._emit);

  static const String _recordMarker = 'MORPH_BENCHMARK ';
  static const String _chunkMarker = 'MORPH_BENCHMARK_CHUNK ';
  static const int _maximumLogLineLength = 3000;
  static const int _maximumChunkPayloadLength = 2600;

  final void Function(String message) _emit;
  final List<Map<String, Object>> _records = <Map<String, Object>>[];
  int _nextChunkedRecordId = 0;

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
      _emitRecord(jsonEncode(record));
    }
  }

  void _emitRecord(String encodedRecord) {
    final line = '$_recordMarker$encodedRecord';
    if (line.length <= _maximumLogLineLength) {
      _emit(line);
      return;
    }

    final encodedPayload = base64Encode(utf8.encode(encodedRecord));
    final chunkRatio = encodedPayload.length / _maximumChunkPayloadLength;
    final chunkCount = chunkRatio.ceil();
    final recordId = _nextChunkedRecordId++;
    for (var index = 0; index < chunkCount; index += 1) {
      final start = index * _maximumChunkPayloadLength;
      final end = math.min(
        start + _maximumChunkPayloadLength,
        encodedPayload.length,
      );
      final chunk = <String, Object>{
        'record': recordId,
        'index': index,
        'count': chunkCount,
        'payload': encodedPayload.substring(start, end),
      };
      _emit('$_chunkMarker${jsonEncode(chunk)}');
    }
  }
}
