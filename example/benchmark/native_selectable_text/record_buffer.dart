import 'dart:convert';
import 'dart:math' as math;

/// Emits complete NativeSelectableText benchmark records within log limits.
final class NativeSelectableTextBenchmarkRecordBuffer {
  /// Creates a record buffer that writes messages through [emit].
  NativeSelectableTextBenchmarkRecordBuffer(this.emit);

  static const String recordMarker = 'NATIVE_SELECTABLE_TEXT_BENCHMARK ';
  static const String chunkMarker = 'NATIVE_SELECTABLE_TEXT_BENCHMARK_CHUNK ';
  static const int _maximumLogLineLength = 3000;
  static const int _maximumChunkPayloadLength = 2500;

  /// Callback that receives each bounded log message.
  final void Function(String message) emit;

  final List<Map<String, Object>> _records = <Map<String, Object>>[];
  int _nextChunkedRecordId = 0;

  /// Buffers [record] until [flush] is called.
  void add(Map<String, Object> record) {
    _records.add(Map<String, Object>.unmodifiable(record));
  }

  /// Emits buffered records in insertion order and clears the buffer.
  void flush() {
    if (_records.isEmpty) return;
    final records = List<Map<String, Object>>.of(
      _records,
      growable: false,
    );
    _records.clear();
    for (final record in records) {
      _emitRecord(jsonEncode(record));
    }
  }

  void _emitRecord(String encodedRecord) {
    final line = '$recordMarker$encodedRecord';
    if (line.length <= _maximumLogLineLength) {
      emit(line);
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
      emit(
        '$chunkMarker${jsonEncode(<String, Object>{
          'record': recordId,
          'index': index,
          'count': chunkCount,
          'payload': encodedPayload.substring(start, end),
        })}',
      );
    }
  }
}
