import 'dart:convert';
import 'dart:math' as math;

/// Buffers InteractiveSwipeDismiss benchmark records until timing finishes.
final class InteractiveSwipeDismissBenchmarkRecordBuffer {
  /// Creates a record buffer that emits complete benchmark log lines.
  InteractiveSwipeDismissBenchmarkRecordBuffer(this._emit);

  /// Prefix used for a complete JSON benchmark record.
  static const String recordMarker = 'INTERACTIVE_SWIPE_DISMISS_BENCHMARK ';

  /// Prefix used for one bounded part of a base64-encoded record.
  static const String chunkMarker = '${recordMarker}CHUNK ';
  static const int _maximumLogLineLength = 900;
  static const int _maximumChunkPayloadLength = 768;

  final void Function(String message) _emit;
  final List<Map<String, Object>> _records = <Map<String, Object>>[];
  int _nextChunkedRecordId = 0;

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
    final line = '$recordMarker$encodedRecord';
    if (line.length <= _maximumLogLineLength) {
      _emit(line);
      return;
    }

    final encodedPayload = base64Encode(utf8.encode(encodedRecord));
    final payloadLength = encodedPayload.length;
    final chunkCount = (payloadLength / _maximumChunkPayloadLength).ceil();
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
      _emit('$chunkMarker${jsonEncode(chunk)}');
    }
  }
}
