import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('when the receiver retires a prepared result, it should release its owned foreground carrier', () {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint());
    final carrier = recorder.endRecording();
    ContourCompositeResult(
      picture: carrier,
      boundsPx: const ui.Rect.fromLTWH(0, 0, 2, 2),
    ).dispose();
    expect(carrier.debugDisposed, true);
  });
}
