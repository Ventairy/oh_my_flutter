import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'contour_native_port_bindings.dart';
import 'contour_native_port_request.dart';
import 'contour_native_port_result.dart';

/// Traces copied widget pixels while retaining native ownership until retirement.
final class ContourNativePortSession implements Finalizable {
  new _();

  /// Checks platform support without initializing bindings or opening a port.
  static bool get isSupported => Platform.isAndroid || Platform.isMacOS;

  /// Reports the actual Android host without initializing native bindings.
  static bool get isAndroid => Platform.isAndroid;

  /// Lazily opens a session and attaches native ownership in one non-leaf call.
  @RecordUse()
  static ContourNativePortSession? create() {
    if (!isSupported) return null;
    final session = ContourNativePortSession._();
    session._ownerId = ContourNativePortBindings.open(
      session,
      NativeApi.initializeApiDLData,
    );
    if (session._ownerId == 0) return null;
    return session;
  }

  late final int _ownerId;
  final _pending = <int, ContourNativePortRequest>{};
  Future<void>? _closeFuture;
  bool _closing = false;

  /// Identifies this owner even after its native close acknowledgment.
  int get ownerId => _ownerId;

  /// Lists tickets still waiting for both result and retirement, or close ACK.
  List<int> get pendingTickets => List.unmodifiable(_pending.keys);

  /// Reports native ownership, allocation, and tracing counters.
  ///
  /// Remains readable after this owner has closed.
  Map<String, int> get stats => {
    for (final (index, name) in const [
      (0, 'initialized'),
      (1, 'owners'),
      (2, 'queued'),
      (3, 'active'),
      (4, 'heldBytes'),
      (7, 'ownerCloses'),
      (8, 'drained'),
      (9, 'posted'),
      (10, 'postFailures'),
      (11, 'portsCreated'),
      (12, 'maximumActive'),
      (13, 'jobs'),
      (14, 'nativeOutAndWorkspaceBytes'),
      (15, 'calls'),
      (16, 'acks'),
      (17, 'cInputCopies'),
      (18, 'inputBytesSubmitted'),
      (19, 'currentIsolateChecks'),
      (20, 'handlerAffinityChecks'),
      (21, 'handlerAffinityFailures'),
      (22, 'handlerAffinityUnion'),
      (23, 'firstHandlerAffinity'),
      (26, 'copiedOutputBytesPosted'),
      (27, 'kernelOutputBytes'),
      (28, 'status0'),
      (29, 'status1'),
      (30, 'status2'),
      (31, 'status3'),
      (32, 'status4'),
      (33, 'peakNativeBytes'),
    ])
      name: ContourNativePortBindings.stat(index),
  };

  /// Returns geometry only after both the copied reply and native retirement.
  Future<ContourNativePortResult?> trace(
    Uint8List rgba, {
    required int width,
    required int height,
    required double pixelRatio,
    required int totalQuota,
    int? ticket,
  }) {
    assert(width > 0, 'Source width must be positive.');
    assert(height > 0, 'Source height must be positive.');
    assert(
      rgba.length == width * height * 4,
      'Source bytes must cover the complete RGBA rectangle.',
    );
    assert(
      pixelRatio.isFinite && pixelRatio > 0,
      'Source pixel ratio must be finite and positive.',
    );
    assert(totalQuota > 0, 'Native admission quota must be positive.');
    assert(
      ticket == null || ticket > 0,
      'Explicit native tickets must be positive.',
    );
    if (_closing) throw StateError('NativePort contour session is closing.');
    final key = ticket ?? ContourNativePortBindings.nextTicket();
    if (_pending.containsKey(key)) throw StateError('NativePort contour ticket is already pending.');
    final request = ContourNativePortRequest(
      ticket: key,
      onComplete: (decodingError) {
        // A decoding failure gives the caller no result ticket to acknowledge.
        // The request invokes this only after retirement or native close ACK.
        if (decodingError != null) ContourNativePortBindings.ack(_ownerId, key);
        _pending.remove(key);
      },
    );
    _pending[key] = request;
    try {
      final message = <Object>[
        request.sendPort,
        _ownerId,
        key,
        rgba,
        width,
        height,
        pixelRatio,
        totalQuota,
      ];
      final status = ContourNativePortBindings.submit(
        message,
        _ownerId,
        key,
        rgba.length,
        totalQuota,
      );
      if (status != 0) {
        throw StateError(
          'NativePort contour admission or atomic post failed: $status',
        );
      }
    } catch (_) {
      _pending.remove(key);
      request.discardUnposted();
      rethrow;
    }
    return request.future;
  }

  /// Releases admission after the caller has consumed this ticket's geometry.
  void ack(int ticket) => ContourNativePortBindings.ack(_ownerId, ticket);

  /// Cancels pending requests only after native cleanup has been acknowledged.
  Future<void> close() {
    if (_closeFuture case final future?) return future;
    final replies = ReceivePort();
    final completion = Completer<void>();
    _closing = true;
    _closeFuture = completion.future;
    replies.listen((message) {
      if (message != _ownerId) return;
      replies.close();
      while (_pending.isNotEmpty) {
        _pending.values.first.completeAfterCloseAck();
      }
      completion.complete();
    });
    try {
      final status = ContourNativePortBindings.closeAsync(
        this,
        _ownerId,
        replies.sendPort.nativePort,
      );
      if (status != 0) {
        throw StateError(
          'NativePort contour asynchronous close failed: $status',
        );
      }
    } catch (_) {
      replies.close();
      _closing = false;
      _closeFuture = null;
      rethrow;
    }
    return completion.future;
  }
}
