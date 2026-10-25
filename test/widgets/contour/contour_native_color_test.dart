import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_native_custom_color.dart';
import 'contour_native_test_harness.dart';

void main() {
  const colors = <String, Color>{
    'black': Color(0xFF000000),
    'red': Color(0xFFEA2341),
    'Display P3': ui.Color.from(alpha: 1, red: .95, green: .12, blue: .35, colorSpace: ui.ColorSpace.displayP3),
  };

  Future<Uint8List> nativePixels(
    WidgetTester tester, {
    required ContourNativeTestHarness harness,
    required Color color,
    required double amount,
    bool filtered = false,
  }) async {
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    final boundary = harness.boundaryKey.currentContext!.findRenderObject()!;
    final origin = paragraph.localToGlobal(Offset.zero, ancestor: boundary);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(4);
    if (filtered) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    for (final stroke in [false, true]) {
      final paint = Paint()
        ..color = filtered ? const Color(0xFFFFFFFF) : color
        ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = amount * 2
        ..strokeJoin = StrokeJoin.round;
      final span = paragraph.text as TextSpan;
      TextPainter(
          text: TextSpan(
            text: span.text,
            style: span.style!.copyWith(foreground: paint),
          ),
          textDirection: paragraph.textDirection,
        )
        ..layout(minWidth: paragraph.constraints.minWidth, maxWidth: paragraph.constraints.maxWidth)
        ..paint(canvas, origin)
        ..dispose();
    }
    if (filtered) canvas.restore();
    TextPainter(text: paragraph.text, textDirection: paragraph.textDirection)
      ..layout(minWidth: paragraph.constraints.minWidth, maxWidth: paragraph.constraints.maxWidth)
      ..paint(canvas, origin)
      ..dispose();
    final picture = recorder.endRecording();
    try {
      final image = await tester.runAsync(() => picture.toImage(400, 400));
      try {
        final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
        return data!.buffer.asUint8List();
      } finally {
        image!.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  Future<void> compareNativeColor(
    WidgetTester tester, {
    required Color color,
    required double amount,
    String fontFamily = 'Ahem',
    bool filtered = false,
  }) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(
      tester,
      color: color,
      amount: amount,
      pixelRatio: 2,
      child: Text(
        'Oo',
        style: TextStyle(fontFamily: fontFamily, fontSize: 28, height: 1, color: const Color(0xFF16B8E2)),
      ),
    );
    final actual = await harness.pixels(tester, pixelRatio: 4);
    final reference = await nativePixels(tester, harness: harness, color: color, amount: amount, filtered: filtered);
    expect(<Object?>[harness.diagnostic('nativeTextActive'), actual], <Object?>[true, reference]);
  }

  for (final amount in [.5, 8.0]) {
    for (final color in colors.entries) {
      testWidgets(
        'when the ${color.key} contour has amount $amount, it should match native colored glyph strokes',
        (
          tester,
        ) => compareNativeColor(tester, color: color.value, amount: amount),
      );
    }
  }

  group('curved native glyph colors', () {
    setUpAll(() async {
      await (FontLoader('ContourNativeColorInter')..addFont(
            File('test/fixtures/fonts/inter.ttf').readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    });

    for (final amount in [.5, 8.0]) {
      for (final color in colors.entries) {
        testWidgets(
          'when curved ${color.key} glyphs have amount $amount, it should match native colored strokes',
          (
            tester,
          ) => compareNativeColor(tester, color: color.value, amount: amount, fontFamily: 'ContourNativeColorInter'),
        );
      }
    }
  }, skip: kIsWeb ? 'The curved font fixture is not bundled into browser tests.' : false);

  for (final amount in [.5, 8.0]) {
    testWidgets(
      'when a native contour is translucent at amount $amount, it should apply opacity to the complete mask',
      (
        tester,
      ) => compareNativeColor(tester, color: const Color(0x70EA2341), amount: amount, filtered: true),
    );
  }

  testWidgets(
    'when a native contour uses a custom color, it should preserve color filter behavior',
    (
      tester,
    ) => compareNativeColor(tester, color: const ContourNativeCustomColor(), amount: 3, filtered: true),
  );

  testWidgets('when the source color changes, it should match the newest native glyph colors', (tester) async {
    final harness = ContourNativeTestHarness();
    const color = Color(0xFFEA2341);
    for (final source in [const Color(0xFF16B8E2), const Color(0xFF834CF1), const Color(0xFFFFB026)]) {
      await harness.mount(
        tester,
        color: color,
        amount: 3,
        pixelRatio: 2,
        child: Text(
          'Ab',
          style: TextStyle(fontFamily: 'Ahem', fontSize: 26, height: 1, color: source),
        ),
      );
    }
    final actual = await harness.pixels(tester, pixelRatio: 4);
    final reference = await nativePixels(tester, harness: harness, color: color, amount: 3);
    expect(<Object?>[harness.diagnostic('nativeTextActive'), actual], <Object?>[true, reference]);
  });

  testWidgets('when opaque color animates, it should retain glyph geometry and paint the final native color', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    const child = Text(
      'Cd',
      style: TextStyle(fontFamily: 'Ahem', fontSize: 27, height: 1, color: Color(0xFF167A91)),
    );
    await harness.mount(tester, color: const Color(0xFF000000), amount: 3, pixelRatio: 2, child: child);
    final initialCreations = harness.diagnostic('nativeFillPainterCreations');
    final initialLayouts = harness.diagnostic('nativeFillLayoutBuilds');
    final initialUpdates = harness.diagnostic('nativeFillPaintUpdates')! as int;
    final initialCaptures = harness.captureCount;
    final initialVerifications = harness.diagnostic('nativeTextVerificationCount');
    final initialSource = harness.diagnostic('nativeMaskSourceId');
    final states =
        <
          ({
            Object? fillPainters,
            Object? geometryBuilds,
            int captures,
            Object? verifications,
            bool sameSource,
            Object? native,
          })
        >[];
    var color = const Color(0xFF000000);
    for (var frame = 1; frame <= 24; frame++) {
      color = Color.fromARGB(255, frame * 7 % 255, frame * 11 % 255, frame * 19 % 255);
      await harness.mount(tester, color: color, amount: 3, pixelRatio: 2, child: child);
      states.add((
        fillPainters: harness.diagnostic('nativeFillPainterCreations'),
        geometryBuilds: harness.diagnostic('nativeFillLayoutBuilds'),
        captures: harness.captureCount,
        verifications: harness.diagnostic('nativeTextVerificationCount'),
        sameSource: identical(harness.diagnostic('nativeMaskSourceId'), initialSource),
        native: harness.diagnostic('nativeTextActive'),
      ));
    }
    final actual = await harness.pixels(tester, pixelRatio: 4);
    final reference = await nativePixels(tester, harness: harness, color: color, amount: 3);
    expect(
      <Object?>[
        initialCreations,
        initialLayouts,
        states,
        (harness.diagnostic('nativeFillPaintUpdates')! as int) > initialUpdates,
        actual,
      ],
      <Object?>[
        1,
        1,
        List.filled(24, (
          fillPainters: 1,
          geometryBuilds: 1,
          captures: initialCaptures,
          verifications: initialVerifications,
          sameSource: true,
          native: true,
        )),
        true,
        reference,
      ],
    );
  });
}
