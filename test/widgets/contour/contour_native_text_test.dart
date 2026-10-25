import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_native_test_harness.dart';
import 'contour_test_harness.dart';

void main() {
  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final size in [24.0, 30.0]) {
    testWidgets('when a heart icon has size $size, it should preserve native stroke eligibility', (tester) async {
      final harness = ContourNativeTestHarness();
      await harness.mount(tester, amount: 3, child: Icon(Icons.favorite, size: size));
      expect(harness.diagnostic('nativeTextActive'), isTrue);
    }, skip: kIsWeb);
  }

  testWidgets('when only amount changes, it should retain the accepted proof', (tester) async {
    final harness = ContourNativeTestHarness();
    for (final amount in [0.0, .5, 8.0, 0.0, 3.0]) {
      await harness.mount(tester, amount: amount, child: ContourNativeTestHarness.glyph);
    }
    expect(harness.diagnostic('nativeTextVerificationCount'), 1);
  });

  testWidgets('when glyphs change repeatedly during generation, it should display the newest source', (tester) async {
    final harness = ContourNativeTestHarness();
    Widget build(String glyph) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: harness.boundaryKey,
          child: SizedBox.square(
            dimension: 100,
            child: Center(
              child: Contour(
                key: harness.backdropKey,
                color: Colors.white,
                amount: 3,
                child: Text(glyph, style: const TextStyle(fontFamily: 'Ahem', fontSize: 24)),
              ),
            ),
          ),
        ),
      ),
    );
    for (final glyph in ['A', 'BB', 'CCC']) {
      await tester.pumpWidget(build(glyph));
    }
    await ContourTestHarness.settle(tester);
    final actual = await harness.pixels(tester, pixelRatio: 4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(build('CCC'));
    await ContourTestHarness.settle(tester);
    expect(actual, await harness.pixels(tester, pixelRatio: 4));
  });

  testWidgets('when disposed during native preparation, it should release all pending work', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Contour(color: Colors.white, child: ContourNativeTestHarness.glyph),
            Contour(color: Colors.white, child: ContourNativeTestHarness.glyph),
          ],
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(tester.takeException(), isNull);
  });

  for (final (size, expectedNative) in [(85.0, true), (100.0, false)]) {
    testWidgets('when a wide glyph run has size $size, it should keep proof within its reserved capacity', (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      final key = GlobalKey();
      await harness.mount(
        tester,
        color: const Color(0x00000000),
        child: OverflowBox(
          minWidth: size * 6,
          maxWidth: size * 6,
          minHeight: size,
          maxHeight: size,
          child: Contour(
            key: key,
            color: Colors.white,
            amount: 3,
            child: Text(
              'OOOOOO',
              style: TextStyle(fontFamily: 'Ahem', fontSize: size, height: 1, color: const Color(0xFF000000)),
            ),
          ),
        ),
      );
      expect(
        (
          harness.diagnostic('contourReady', key: key),
          harness.diagnostic('nativeTextActive', key: key),
          harness.diagnostic('nativeTextVerificationCount', key: key),
          harness.diagnostic('workBudgetActiveBytes', key: key),
        ),
        (true, expectedNative, expectedNative ? 1 : 0, 0),
      );
    });
  }

  group('resolved font updates', () {
    testWidgets('when the loaded font changes, it should verify the refreshed glyphs', (tester) async {
      final harness = ContourNativeTestHarness();
      await harness.mount(tester, amount: 3, child: ContourNativeTestHarness.glyph);
      final before = harness.diagnostic('nativeTextVerificationCount')! as int;
      await tester.runAsync(
        () =>
            (FontLoader('ContourNativeFontRefresh')..addFont(
                  File('test/fixtures/fonts/inter.ttf').readAsBytes().then(ByteData.sublistView),
                ))
                .load(),
      );
      await tester.pump();
      await ContourTestHarness.settle(tester);
      expect(harness.diagnostic('nativeTextVerificationCount'), greaterThan(before));
    });
  }, skip: kIsWeb ? 'The local font fixture is not bundled into browser tests.' : false);
}
