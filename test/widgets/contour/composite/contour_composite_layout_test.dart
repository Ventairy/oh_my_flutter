@TestOn('vm')
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'when neighboring atlas cells use different colors, it should preserve the decoration pixels of each owner',
    (
      tester,
    ) async {
      final colors = await tester.runAsync(() async {
        final cancel = Completer<void>();
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder)
            .drawRect(const ui.Rect.fromLTWH(2, 2, 4, 4), ui.Paint()..color = const ui.Color(0xFF000000));
        final picture = recorder.endRecording();
        final pending = [
          for (final color in [0xFFFF0000, 0xFF0000FF])
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
              cancelled: cancel.future,
            ),
        ];
        picture.dispose();
        final outputs = await Future.wait(pending);
        final result = <List<int>>[];
        for (final output in outputs) {
          final image = await output!.picture.toImage(8, 8);
          try {
            final data = (await image.toByteData())!;
            result.add([
              for (var component = 0; component < 4; component++) data.getUint8((3 * 8 + 3) * 4 + component),
            ]);
          } finally {
            image.dispose();
            output.dispose();
          }
        }
        cancel.complete();
        return result;
      });
      expect(colors, [
        [255, 0, 0, 255],
        [0, 0, 255, 255],
      ]);
    },
  );
}
