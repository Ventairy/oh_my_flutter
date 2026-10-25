import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_shadow_atlas_test_harness.dart';

void main() {
  const shadows = [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))];
  const fixtureFont = 'ContourAtlasSourceFixture';

  setUpAll(() async {
    if (kIsWeb) return;
    final loader = FontLoader(fixtureFont)
      ..addFont(File('test/fixtures/fonts/inter.ttf').readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });

  for (final removeFirst in [false, true]) {
    testWidgets(
      'when the first source ${removeFirst ? 'detaches' : 'changes'} before dispatch, it should preserve the waiting follower',
      (tester) async {
        final harness = ContourShadowAtlasTestHarness();
        await harness.animate(tester);
        final reference = await harness.pixels(tester);
        await harness.mount(
          tester,
          count: 2,
          amount: 4,
          shadows: const [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(1, 2))],
          settle: false,
        );
        await harness.mount(tester, count: 2, amount: 4, shadows: shadows, settle: false);
        await harness.mount(
          tester,
          count: 2,
          amount: 4,
          shadows: shadows,
          settle: false,
          duration: const Duration(milliseconds: 120),
          showFor: removeFirst ? (index) => index != 0 : null,
          childFor: removeFirst
              ? null
              : (index) => Text(
                  index == 0 ? 'WW' : 'OO',
                  style: const TextStyle(fontFamily: 'Ahem', fontSize: 18, color: Color(0xFFFF0000)),
                ),
        );
        await harness.settle(tester);
        const follower = 1;
        final actual = await harness.pixels(tester);
        var maximumDifference = 0;
        for (var y = 0; y < 70; y++) {
          for (var x = 0; x < 80; x++) {
            for (var channel = 0; channel < 4; channel++) {
              final difference =
                  (reference[(y * 640 + x + follower * 80) * 4 + channel] -
                          actual[(y * 640 + x + follower * 80) * 4 + channel])
                      .abs();
              if (difference > maximumDifference) maximumDifference = difference;
            }
          }
        }
        expect(
          (harness.property('shadowAtlasReady', follower), maximumDifference),
          (true, 0),
          reason: 'maximum channel difference: $maximumDifference',
        );
      },
    );
  }

  for (final afterComposition in [false, true]) {
    testWidgets(
      'when a native source changes ${afterComposition ? 'after composition' : 'between frames'}, it should preserve the waiting follower',
      (tester) async {
        const style = TextStyle(fontFamily: fixtureFont, fontSize: 18, color: Color(0xFFFF0000));
        Widget source(int _) => const Text('OO', style: style);
        final harness = ContourShadowAtlasTestHarness();
        await harness.animate(tester, childFor: source);
        final native = harness.property('nativeTextActive');
        final reference = await harness.pixels(tester);
        await harness.mount(
          tester,
          count: 2,
          amount: 4,
          shadows: const [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(1, 2))],
          childFor: source,
          settle: false,
        );
        await harness.mount(tester, count: 2, amount: 4, shadows: shadows, childFor: source, settle: false);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.byKey(harness.keys.first), matching: find.byType(RichText)),
        );
        // A source can receive new paint before its next composition validates it.
        if (afterComposition) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            paragraph.text = const TextSpan(text: 'WW', style: style);
          });
        } else {
          paragraph.text = const TextSpan(text: 'WW', style: style);
        }
        await tester.pump(const Duration(milliseconds: 120));
        await harness.settle(tester);
        final actual = await harness.pixels(tester);
        var maximumDifference = 0;
        for (var y = 0; y < 70; y++) {
          for (var x = 0; x < 80; x++) {
            for (var channel = 0; channel < 4; channel++) {
              final index = (y * 640 + x + 80) * 4 + channel;
              final difference = (reference[index] - actual[index]).abs();
              if (difference > maximumDifference) maximumDifference = difference;
            }
          }
        }
        expect(
          (native, harness.property('shadowAtlasReady', 1), maximumDifference),
          (true, true, 0),
          reason: 'maximum channel difference: $maximumDifference',
        );
      },
      skip: kIsWeb,
    );
  }
}
