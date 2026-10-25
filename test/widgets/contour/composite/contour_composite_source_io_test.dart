@TestOn('vm')
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_result.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ui.Picture source() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(2, 2, 4, 4), ui.Paint()..color = const ui.Color(0xFF000000));
    return recorder.endRecording();
  }

  Future<ContourCompositeResult?> submit(ui.Picture picture, Future<void> cancelled, {int color = 0xFFFFFFFF}) =>
      ContourCompositeSource.shared.capturePicture(
        picture,
        width: 8,
        height: 8,
        sourceRatio: 1,
        outputRatio: 1,
        amountOutputPx: 2,
        contourArgb: color,
        shadowArgb: 0,
        shadowSigmaOutputPx: 0,
        shadowDxOutputPx: 0,
        shadowDyOutputPx: 0,
        cancelled: cancelled,
      );

  testWidgets('when seventy sources arrive together, it should split within the native forty-source limit', (
    tester,
  ) async {
    final result = await tester.runAsync(() async {
      final before = ContourNativePortBindings.stat(8);
      final cancel = Completer<void>();
      final pending = <Future<ContourCompositeResult?>>[];
      for (var index = 0; index < 70; index++) {
        final picture = source();
        pending.add(submit(picture, cancel.future));
        picture.dispose();
      }
      final outputs = await Future.wait(pending);
      final actual = {
        'ready': outputs.where((output) => output?.picture != null).length,
        'nativeBatches': ContourNativePortBindings.stat(8) - before,
      };
      for (final output in outputs) {
        output?.dispose();
      }
      cancel.complete();
      return actual;
    });
    expect(result, {'ready': 70, 'nativeBatches': 2});
  }, skip: !ContourNativePortSession.isSupported);

  testWidgets(
    'when a caller disposes its picture immediately, it should retain its independent source until decoration is ready',
    (tester) async {
      final result = await tester.runAsync(() async {
        final cancel = Completer<void>();
        final picture = source();
        final future = submit(picture, cancel.future);
        picture.dispose();
        final output = await future;
        final actual = output != null;
        output?.dispose();
        cancel.complete();
        return actual;
      });
      expect(result, isTrue);
    },
    skip: !ContourNativePortSession.isSupported,
  );
}
