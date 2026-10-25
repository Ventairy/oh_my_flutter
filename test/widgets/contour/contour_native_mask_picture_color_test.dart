import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_native_mask_picture_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContourNativeMaskPictureCache cache;
  late ui.PictureRecorder recorder;
  late ui.Canvas canvas;
  late Object source;

  setUp(() {
    cache = ContourNativeMaskPictureCache.test();
    recorder = ui.PictureRecorder();
    canvas = ui.Canvas(recorder);
    source = Object();
  });
  tearDown(() {
    recorder.endRecording().dispose();
    cache.clear();
  });
  void paint(ui.Color color) => cache.paint(
    canvas,
    sourceId: source,
    amount: 3,
    sourceBytes: 256,
    color: color,
    paint: (target) => target.drawRect(const ui.Rect.fromLTWH(1, 1, 4, 4), ui.Paint()..color = color),
  );

  test('when equal SDK color types repeat a proof, it should reuse its opaque recording', () {
    paint(Colors.red);
    paint(const Color(0xFFF44336));
    paint(Colors.red);
    expect((cache.buildCount, cache.entryCount), (1, 1));
  });
  test('when shadows and foreground request independent colors, it should retain both after reuse', () {
    for (var owner = 0; owner < 20; owner++) {
      paint(Colors.white);
      paint(Colors.black);
    }
    expect((cache.buildCount, cache.entryCount), (2, 2));
  });
  test('when two spaces use the same numeric channels, it should keep their native colors separate', () {
    for (var owner = 0; owner < 3; owner++) {
      paint(const ui.Color.from(alpha: 1, red: .9, green: .1, blue: .3));
      paint(const ui.Color.from(alpha: 1, red: .9, green: .1, blue: .3, colorSpace: ui.ColorSpace.displayP3));
    }
    expect((cache.buildCount, cache.entryCount), (2, 2));
  });
  test('when many colors share one source, it should preserve the existing variant allowance', () {
    for (var color = 0; color < 20; color++) {
      for (var owner = 0; owner < 2; owner++) {
        paint(Color(0xFF000000 | color));
      }
    }
    expect((cache.entryCount, cache.amountCount(source)), (4, 4));
  });
}
