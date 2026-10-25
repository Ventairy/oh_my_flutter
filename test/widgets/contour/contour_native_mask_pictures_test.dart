import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_native_mask_picture_cache.dart';

import 'contour_native_test_harness.dart';
import 'contour_test_harness.dart';

void main() {
  Future<void> mountReused(
    WidgetTester tester,
    ContourNativeTestHarness harness, {
    required Widget child,
    double amount = 3,
    Color color = const Color(0xFFFFFFFF),
    List<Shadow> shadows = const [],
  }) async {
    // A second actual use admits a recording. Repaint the same accepted source
    // while preserving its native proof and its final visible configuration.
    await harness.mount(tester, amount: amount, color: color, shadows: shadows, child: child);
    await harness.mount(
      tester,
      amount: amount,
      color: color == const Color(0xFF000000) ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      shadows: shadows,
      child: child,
    );
    await harness.mount(tester, amount: amount, color: color, shadows: shadows, child: child);
  }

  testWidgets('when equivalent glyph owners share a proof, it should reuse the same native mask source', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    await harness.mountPair(tester);
    final first = harness.diagnostic('nativeMaskSourceId', key: harness.firstKey);
    final second = harness.diagnostic('nativeMaskSourceId', key: harness.secondKey);
    expect((first != null, identical(first, second)), (true, true));
  });

  testWidgets('when native amount animation visits many values, it should retain at most four pictures for the proof', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    for (final amount in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]) {
      await mountReused(tester, harness, amount: amount, child: ContourNativeTestHarness.glyph);
    }
    final sourceId = harness.diagnostic('nativeMaskSourceId')!;
    expect(ContourNativeMaskPictureCache.instance.amountCount(sourceId), 4);
  });

  testWidgets('when the accepted glyph changes, it should use a new native proof identity', (tester) async {
    final harness = ContourNativeTestHarness();
    await mountReused(tester, harness, child: ContourNativeTestHarness.glyph);
    final before = harness.diagnostic('nativeMaskSourceId');
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'OO',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFFE84A5F)),
      ),
    );
    final after = harness.diagnostic('nativeMaskSourceId');
    expect(before != null && after != null && !identical(before, after), isTrue);
  });

  testWidgets('when source text has an invisible tail, it should still charge its retained glyph resources', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    final text = 'O${List<String>.filled(2000, '\u200B').join()}';
    await mountReused(
      tester,
      harness,
      child: Text(
        text,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
      ),
    );
    expect(
      harness.diagnostic('nativeMaskSourceId') != null &&
          (harness.diagnostic('nativeMaskSourceBytes')! as int) >= text.length * 16 + 256 &&
          (harness.diagnostic('nativeMaskPictureEntries')! as int) > 0,
      isTrue,
    );
  });

  testWidgets('when a native source cannot have a bounded key, it should paint without retaining mask pictures', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(
      tester,
      amount: 3,
      child: Text(
        'O${List<String>.filled(40000, '\u200B').join()}',
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
      ),
    );
    expect(
      (harness.diagnostic('nativeTextActive'), harness.diagnostic('nativeMaskPictureEntries')),
      (true, 0),
    );
  });

  testWidgets('when a colored translucent mask is rebuilt after eviction, it should preserve exact shadowed pixels', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    const color = Color(0x8055AAEE);
    const shadows = [Shadow(color: Color(0x55000000), offset: Offset(2, 3))];
    await mountReused(tester, harness, color: color, shadows: shadows, child: ContourNativeTestHarness.glyph);
    final original = await harness.pixels(tester, pixelRatio: 4);
    for (final amount in [1.0, 2.0, 4.0, 5.0, 3.0]) {
      await mountReused(
        tester,
        harness,
        amount: amount,
        color: color,
        shadows: shadows,
        child: ContourNativeTestHarness.glyph,
      );
    }
    expect(await harness.pixels(tester, pixelRatio: 4), original);
  });

  testWidgets('when system fonts change, it should clear all retained native mask pictures', (tester) async {
    final harness = ContourNativeTestHarness();
    await mountReused(tester, harness, child: ContourNativeTestHarness.glyph);
    final before = ContourNativeMaskPictureCache.instance.entryCount;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.system.name,
      const JSONMessageCodec().encodeMessage(<String, Object>{'type': 'fontsChange'}),
      null,
    );
    expect((before > 0, ContourNativeMaskPictureCache.instance.entryCount), (true, 0));
  });

  testWidgets('when a font change is verified again, it should issue a fresh native proof identity', (tester) async {
    final harness = ContourNativeTestHarness();
    await mountReused(tester, harness, child: ContourNativeTestHarness.glyph);
    final before = harness.diagnostic('nativeMaskSourceId');
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.system.name,
      const JSONMessageCodec().encodeMessage(<String, Object>{'type': 'fontsChange'}),
      null,
    );
    await tester.pump();
    await ContourTestHarness.settle(tester);
    final after = harness.diagnostic('nativeMaskSourceId');
    expect(before != null && after != null && !identical(before, after), isTrue);
  });

  testWidgets('when the last contour is removed, it should release all retained native mask pictures', (tester) async {
    final harness = ContourNativeTestHarness();
    await mountReused(tester, harness, child: ContourNativeTestHarness.glyph);
    final before = ContourNativeMaskPictureCache.instance.entryCount;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      (
        before > 0,
        ContourNativeMaskPictureCache.instance.entryCount,
        ContourNativeMaskPictureCache.instance.estimatedBytes,
      ),
      (true, 0, 0),
    );
  });

  testWidgets('when a snapshot starts before the last owner is removed, it should preserve the captured native mask', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    await mountReused(tester, harness, child: ContourNativeTestHarness.glyph);
    final expected = await harness.pixels(tester);
    final boundary = harness.boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final snapshot = boundary.toImage();
    await tester.pumpWidget(const SizedBox.shrink());
    final image = await tester.runAsync(() => snapshot);
    try {
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      expect(bytes!.buffer.asUint8List(), expected);
    } finally {
      image!.dispose();
    }
  });

  testWidgets(
    'when an exported scene outlives the last owner, it should retain its native mask pixels',
    (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      await mountReused(tester, harness, child: ContourNativeTestHarness.glyph);
      final expected = await harness.pixels(tester);
      final boundary = harness.boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final layer = boundary.debugLayer! as OffsetLayer;
      final builder = ui.SceneBuilder()..pushOffset(-layer.offset.dx, -layer.offset.dy);
      final scene = layer.buildScene(builder);
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        final image = await tester.runAsync(() => scene.toImage(100, 100));
        try {
          final actual = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
          expect(actual!.buffer.asUint8List(), expected);
        } finally {
          image!.dispose();
        }
      } finally {
        scene.dispose();
      }
    },
    // CanvasKit also invalidates a plain Flutter ColoredBox's retained scene
    // when its original engine layers are removed. Active snapshots and owned
    // picture scenes have separate cross-platform lifetime regressions.
    skip: kIsWeb,
  );
}
