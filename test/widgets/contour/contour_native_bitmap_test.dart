import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;

import 'contour_native_test_harness.dart';
import 'contour_test_harness.dart';

void main() {
  // Exercise bitmap stroke rejection and proof sharing on the sampled fallback.
  setUp(() => ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared);
  tearDown(() => ContourCompositeSource.testOverride = null);

  const bitmapFamily = 'ContourNativeBitmapFixture';
  const vectorFamily = 'ContourNativeVectorFixture';

  Future<Uint8List> captureBitmap({required bool stroke}) async {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'x',
        style: TextStyle(
          fontFamily: bitmapFamily,
          fontSize: 40,
          foreground: Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
            ..strokeWidth = 16
            ..strokeJoin = StrokeJoin.round,
        ),
      ),
    )..layout();
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Offset(20, 20));
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(100, 100);
      try {
        final pixels = await image.toByteData();
        return pixels!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      painter.dispose();
      picture.dispose();
    }
  }

  Future<List<GlobalKey>> mountBitmapGrid(WidgetTester tester) async {
    final keys = List<GlobalKey>.generate(40, (_) => GlobalKey());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 480,
            child: Wrap(
              children: [
                for (final key in keys)
                  SizedBox.square(
                    dimension: 60,
                    child: Center(
                      child: Contour(
                        key: key,
                        color: const Color(0xFF000000),
                        amount: 3,
                        child: const Text(
                          'x',
                          style: TextStyle(fontFamily: bitmapFamily, fontSize: 40, color: Color(0xFFFFFFFF)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    return keys;
  }

  group('mixed bitmap font fallback', () {
    setUpAll(() async {
      await ui.loadFontFromList(
        File('test/fixtures/fonts/contour_native/contour_mixed_bitmap.ttf').readAsBytesSync(),
        fontFamily: bitmapFamily,
      );
      await ui.loadFontFromList(
        File('test/fixtures/fonts/contour_native/contour_vector.ttf').readAsBytesSync(),
        fontFamily: vectorFamily,
      );
    });

    testWidgets('when the bitmap fixture is painted, it should contain visible pixels', (tester) async {
      final pixels = await tester.runAsync(() => captureBitmap(stroke: false));
      var visible = 0;
      for (var index = 3; index < pixels!.length; index += 4) {
        if (pixels[index] > 0) visible++;
      }
      expect(visible, greaterThan(0));
    });

    testWidgets('when the bitmap fixture receives a native stroke, it should keep its unstroked pixels', (
      tester,
    ) async {
      final fill = await tester.runAsync(() => captureBitmap(stroke: false));
      final stroke = await tester.runAsync(() => captureBitmap(stroke: true));
      expect(stroke, fill);
    });

    testWidgets('when a small bitmap shares a large vector paragraph, it should keep the captured contour', (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Contour(
              key: harness.backdropKey,
              color: const Color(0xFF000000),
              amount: 8,
              child: const Text.rich(
                TextSpan(
                  style: TextStyle(fontFamily: vectorFamily, fontSize: 40, color: Color(0xFFFF9900)),
                  children: [
                    TextSpan(text: 'AAAAAAAAAAAAAAAAAAAA '),
                    TextSpan(
                      text: 'x',
                      style: TextStyle(fontFamily: bitmapFamily, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await ContourTestHarness.settle(tester);
      expect(harness.diagnostic('nativeTextActive'), isFalse);
    });

    testWidgets('when forty identical bitmap glyphs mount, it should capture one instance', (tester) async {
      final harness = ContourNativeTestHarness();
      final keys = await mountBitmapGrid(tester);
      expect(keys.where((key) => (harness.diagnostic('captureCount', key: key)! as int) > 0).length, 1);
    });

    testWidgets('when forty identical bitmap glyphs mount, it should verify their stroke once', (tester) async {
      final harness = ContourNativeTestHarness();
      final keys = await mountBitmapGrid(tester);
      expect(
        keys.fold<int>(
          0,
          (total, key) => total + (harness.diagnostic('nativeTextVerificationCount', key: key)! as int),
        ),
        1,
      );
    });

    testWidgets('when a bitmap rejection is shared, it should keep every instance on captured contours', (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      final keys = await mountBitmapGrid(tester);
      expect(keys.every((key) => harness.diagnostic('nativeTextActive', key: key) == false), isTrue);
    });

    testWidgets('when a rejected bitmap font is reloaded, it should share a fresh rejected proof', (tester) async {
      final harness = ContourNativeTestHarness();
      final keys = await mountBitmapGrid(tester);
      final beforeCaptures = keys.fold<int>(
        0,
        (total, key) => total + (harness.diagnostic('captureCount', key: key)! as int),
      );
      final beforeVerifications = keys.fold<int>(
        0,
        (total, key) => total + (harness.diagnostic('nativeTextVerificationCount', key: key)! as int),
      );
      final beforeTraces = keys.fold<int>(
        0,
        (total, key) => total + (harness.diagnostic('traceCaptureCount', key: key)! as int),
      );
      final beforeProofs = keys.fold<int>(
        0,
        (total, key) => total + (harness.diagnostic('proofCaptureCount', key: key)! as int),
      );
      await tester.runAsync(
        () => ui.loadFontFromList(
          File('test/fixtures/fonts/contour_native/contour_mixed_bitmap.ttf').readAsBytesSync(),
          fontFamily: bitmapFamily,
        ),
      );
      await tester.pump();
      await ContourTestHarness.settle(tester);
      expect(
        (
          keys.fold<int>(0, (total, key) => total + (harness.diagnostic('captureCount', key: key)! as int)) -
              beforeCaptures,
          keys.fold<int>(0, (total, key) => total + (harness.diagnostic('traceCaptureCount', key: key)! as int)) -
              beforeTraces,
          keys.fold<int>(0, (total, key) => total + (harness.diagnostic('proofCaptureCount', key: key)! as int)) -
              beforeProofs,
          keys.fold<int>(
                0,
                (total, key) => total + (harness.diagnostic('nativeTextVerificationCount', key: key)! as int),
              ) -
              beforeVerifications,
          keys.every((key) => harness.diagnostic('nativeTextActive', key: key) == false),
        ),
        (2, 1, 1, 1, true),
      );
    });
  }, skip: kIsWeb ? 'The authored font fixtures are not bundled into browser tests.' : false);
}
