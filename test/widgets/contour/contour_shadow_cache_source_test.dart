import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_native_mask_picture_cache.dart';

import 'contour_shadow_atlas_test_harness.dart';

void main() {
  const fixtureFont = 'ContourShadowCacheSourceFixture';
  const shadows = [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))];

  setUpAll(() async {
    if (kIsWeb) return;
    final loader = FontLoader(fixtureFont)
      ..addFont(File('test/fixtures/fonts/inter.ttf').readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });

  for (final afterComposition in [false, true]) {
    testWidgets(
      'when an evicted native mask source changes ${afterComposition ? 'after composition' : 'between frames'}, it should preserve the waiting static shadow follower',
      (tester) async {
        const style = TextStyle(fontFamily: fixtureFont, fontSize: 18, color: Color(0xFFFF0000));
        Widget source(int _) => const Text('OO', style: style);
        final harness = ContourShadowAtlasTestHarness();
        await harness.mount(tester, count: 2, amount: 4, shadows: shadows, childFor: source);
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
        void changeSource() {
          // Native recordings are optional and can be evicted. A retained OO
          // picture would otherwise hide a snapshot reading the changed source.
          ContourNativeMaskPictureCache.instance.clear();
          paragraph.text = const TextSpan(text: 'WW', style: style);
        }

        // Deferred snapshots must validate their source again after callbacks
        // that can change a paragraph without composing another contour scene.
        if (afterComposition) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            changeSource();
          });
        } else {
          changeSource();
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
          (
            native,
            harness.property('shadowCacheReady', 1),
            harness.property('shadowAtlasBuildCount', 1),
            maximumDifference,
          ),
          (true, true, 0, 0),
          reason: 'maximum channel difference: $maximumDifference',
        );
      },
      skip: kIsWeb,
    );
  }
}
