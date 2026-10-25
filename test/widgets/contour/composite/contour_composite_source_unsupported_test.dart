import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('when a platform has no composite backend, it should decline without taking ownership of the source', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    final picture = recorder.endRecording();
    try {
      final result = await unsupported.ContourCompositeSource.shared.capturePicture(
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
        cancelled: Completer<void>().future,
      );
      expect(
        (unsupported.ContourCompositeSource.shared.available, result, picture.debugDisposed),
        (false, null, false),
      );
    } finally {
      picture.dispose();
    }
  });
}
