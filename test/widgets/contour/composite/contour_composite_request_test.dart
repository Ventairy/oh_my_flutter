@TestOn('vm')
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_result.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ui.Picture source() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(2, 2, 4, 4), ui.Paint()..color = const ui.Color(0xFF000000));
    return recorder.endRecording();
  }

  Future<ContourCompositeResult?> submit(ui.Picture picture, Future<void> cancelled) =>
      ContourCompositeSource.shared.capturePicture(
        picture,
        width: 8,
        height: 8,
        sourceRatio: 1,
        outputRatio: 1,
        amountOutputPx: 2,
        contourArgb: 0xFFFFFFFF,
        shadowArgb: 0,
        shadowSigmaOutputPx: 0,
        shadowDxOutputPx: 0,
        shadowDyOutputPx: 0,
        cancelled: cancelled,
      );

  testWidgets(
    'when all queued sources cancel before flushing, it should avoid creating capture images or native jobs',
    (tester) async {
      final result = await tester.runAsync(() async {
        var images = 0;
        final previous = ui.Image.onCreate;
        ui.Image.onCreate = (image) {
          images++;
          previous?.call(image);
        };
        try {
          final before = ContourNativePortBindings.stat(8);
          final cancel = Completer<void>();
          final picture = source();
          final pending = [for (var index = 0; index < 40; index++) submit(picture, cancel.future)];
          picture.dispose();
          cancel.complete();
          final outputs = await Future.wait(pending);
          return {
            'results': outputs.every((output) => output == null),
            'images': images,
            'nativeBatches': ContourNativePortBindings.stat(8) - before,
          };
        } finally {
          ui.Image.onCreate = previous;
        }
      });
      expect(result, {'results': true, 'images': 0, 'nativeBatches': 0});
    },
  );

  testWidgets('when eighty copied sources are already owned, it should decline the next request without retaining it', (
    tester,
  ) async {
    final result = await tester.runAsync(() async {
      final cancel = Completer<void>();
      final picture = source();
      final pending = [for (var index = 0; index < 81; index++) submit(picture, cancel.future)];
      picture.dispose();
      final rejected = await pending.last;
      cancel.complete();
      final outputs = await Future.wait(pending);
      for (final output in outputs) {
        output?.dispose();
      }
      return rejected;
    });
    expect(result, isNull);
  });
}
