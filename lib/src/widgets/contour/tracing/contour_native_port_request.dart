import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'contour_native_port_result.dart';

/// Keeps a request pending until both its reply and native retirement arrive.
final class ContourNativePortRequest {
  /// Reports decoding failure before completing the caller.
  new({required this.ticket, required this._onComplete}) {
    _port.listen(_receive);
  }

  /// Identifies this request's native admission.
  final int ticket;

  final _port = ReceivePort();
  final _completion = Completer<ContourNativePortResult?>();
  void Function(Object? decodingError)? _onComplete;
  ContourNativePortResult? _result;
  Object? _error;
  StackTrace? _errorStack;
  bool _retired = false;
  bool _finished = false;

  /// Receives the copied geometry only after native storage has retired.
  Future<ContourNativePortResult?> get future => _completion.future;

  /// Receives native result and retirement messages for this request.
  SendPort get sendPort => _port.sendPort;

  /// Reports whether the reply port and completion callback have been released.
  bool get isFinished => _finished;

  /// Releases a rejected request that was never admitted or posted.
  void discardUnposted() {
    _finished = true;
    _port.close();
    _onComplete = null;
  }

  /// Cancels only after the session's native close acknowledgment has arrived.
  void completeAfterCloseAck() {
    if (_finished) return;
    _finish();
    _completion.complete(null);
  }

  void _receive(Object? message) {
    if (_finished || message is! List<Object?> || message.isEmpty || message[0] != ticket) return;
    if (message.length == 2 && message[1] == 6) {
      _retired = true;
    } else {
      try {
        if (message.length != 4 || message[1] is! int || message[2] is! Uint32List || message[3] is! Float64List) {
          throw const FormatException(
            'Native contour reply has an invalid message shape.',
          );
        }
        _result = ContourNativePortResult(
          ticket: ticket,
          status: message[1]! as int,
          lengths: message[2]! as Uint32List,
          values: message[3]! as Float64List,
        );
      } catch (error, stack) {
        _error = error;
        _errorStack = stack;
      }
    }
    if (!_retired || (_result == null && _error == null)) return;
    _finish();
    if (_error case final error?) {
      _completion.completeError(error, _errorStack);
    } else {
      _completion.complete(_result);
    }
  }

  void _finish() {
    _finished = true;
    _port.close();
    final onComplete = _onComplete;
    _onComplete = null;
    onComplete?.call(_error);
  }
}
