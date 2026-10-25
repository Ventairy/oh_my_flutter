import 'dart:async';
import 'dart:ui' as ui;

import 'package:meta/meta.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_capture.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_result.dart';

part 'contour_composite_capture_test_types.dart';

/// Controls captured decoration completion in renderer lifecycle tests.
class ContourCompositeCaptureTestAdapter implements ContourCompositeCapture {
  @visibleForTesting
  /// Creates an isolated capture with explicitly controlled completion.
  new test({required this._onCapture});

  final void Function(ContourCompositeCaptureTestSubmission) _onCapture;
  int _sequence = 0;
  bool _disposed = false;
  final _pending = <int, ({ui.Picture picture, Completer<ContourCompositeResult?> done, int width, int height})>{};

  @override
  bool get available => !_disposed;

  int get pendingCount => _pending.length;

  @override
  Future<ContourCompositeResult?> capturePicture(
    ui.Picture source, {
    required int width,
    required int height,
    required double sourceRatio,
    required double outputRatio,
    required double amountOutputPx,
    required int contourArgb,
    required int shadowArgb,
    required double shadowSigmaOutputPx,
    required double shadowDxOutputPx,
    required double shadowDyOutputPx,
    required Future<void> cancelled,
  }) {
    if (!available || _pending.length >= 40) return Future.value();
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    final picture = recorder.endRecording();
    final id = ++_sequence;
    final done = Completer<ContourCompositeResult?>();
    _pending[id] = (picture: picture, done: done, width: width, height: height);
    unawaited(cancelled.then<void>((_) => decline(id)));
    try {
      _onCapture((
        id: id,
        source: source,
        picture: picture,
        width: width,
        height: height,
        outputRatio: outputRatio,
      ));
    } catch (_) {
      decline(id);
    }
    return done.future;
  }

  /// Completes one pending capture with its independently owned decoration.
  void complete(int id, {ui.Rect? boundsPx, bool sourceTouchesBoundary = false}) {
    final request = _pending.remove(id);
    if (request == null) return;
    request.done.complete(
      ContourCompositeResult(
        picture: request.picture,
        boundsPx: boundsPx ?? ui.Rect.fromLTWH(0, 0, request.width.toDouble(), request.height.toDouble()),
        sourceTouchesBoundary: sourceTouchesBoundary,
      ),
    );
  }

  /// Declines or cancels one pending capture without publishing its picture.
  void decline(int id) {
    final request = _pending.remove(id);
    if (request == null) return;
    request.picture.dispose();
    request.done.complete();
  }

  Future<void> dispose() async {
    _disposed = true;
    _pending.keys.toList().forEach(decline);
  }
}
