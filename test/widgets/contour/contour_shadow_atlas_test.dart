import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_shadow_atlas_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  const shadows = [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))];

  testWidgets('when an amount is static, it should keep using the single shadow image', (tester) async {
    final harness = ContourShadowAtlasTestHarness();
    await harness.mount(tester, count: 2, amount: 4, shadows: shadows);
    expect(harness.property('shadowAtlasBuildCount'), 0);
  });

  testWidgets('when equivalent sources animate amounts, it should share one atlas image', (tester) async {
    final harness = ContourShadowAtlasTestHarness();
    await harness.animate(tester);
    expect(
      (
        harness.property('shadowAtlasReady'),
        harness.property('shadowAtlasResourceId') == harness.property('shadowAtlasResourceId', 1),
      ),
      (true, true),
    );
  });

  testWidgets('when amounts animate above eight, it should prepare an interval around their value', (tester) async {
    final harness = ContourShadowAtlasTestHarness();
    await harness.animate(tester, base: 16);
    expect(
      (
        harness.property('shadowAtlasReady'),
        harness.property('shadowAtlasMinimumAmount'),
        harness.property('shadowAtlasMaximumAmount'),
      ),
      (true, 16.0, 24.0),
    );
  });

  testWidgets('when native shadow opacity totals point two, it should allow static and atlas images', (tester) async {
    final harness = ContourShadowAtlasTestHarness();
    const shadows = [
      Shadow(color: Color.from(alpha: .1, red: 1, green: 0, blue: 0), blurRadius: 6),
      Shadow(color: Color.from(alpha: .1, red: 0, green: 0, blue: 1), blurRadius: 10, offset: Offset(1, 2)),
    ];
    await harness.mount(tester, count: 2, amount: 1, shadows: shadows);
    final staticReady = harness.property('shadowCacheReady');
    await harness.animate(tester, shadows: shadows);
    expect(
      (harness.property('nativeTextActive'), staticReady, harness.property('shadowAtlasReady')),
      (true, true, true),
    );
  });

  for (final opaque in [false, true]) {
    testWidgets(
      'when native shadow opacity ${opaque ? 'is opaque' : 'totals more than point two'}, it should skip both image caches',
      (tester) async {
        final harness = ContourShadowAtlasTestHarness();
        final shadows = opaque
            ? const [Shadow(blurRadius: 6)]
            : const [
                Shadow(color: Color.from(alpha: .11, red: 1, green: 0, blue: 0), blurRadius: 6),
                Shadow(color: Color.from(alpha: .1, red: 0, green: 0, blue: 1), blurRadius: 10, offset: Offset(1, 2)),
              ];
        await harness.mount(tester, count: 2, amount: 1, shadows: shadows);
        final staticReady = harness.property('shadowCacheReady');
        await harness.animate(tester, shadows: shadows);
        expect(
          (
            harness.property('nativeTextActive'),
            staticReady,
            harness.property('shadowCacheReady'),
            harness.property('shadowCacheBuildCount'),
            harness.property('shadowAtlasReady'),
            harness.property('shadowAtlasBuildCount'),
          ),
          (true, false, false, 0, false, 0),
        );
      },
    );
  }

  const genericFixtures = <String, Widget>{
    'custom paint': CustomPaint(size: Size.square(24), painter: ContourTestPainter(circle: true)),
    'box': SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFFFF0000)),
        child: ColoredBox(color: Color(0xFFFF0000)),
      ),
    ),
  };
  for (final fixture in genericFixtures.entries) {
    testWidgets('when opaque shadows surround a generic ${fixture.key}, it should prepare an atlas', (tester) async {
      final harness = ContourShadowAtlasTestHarness();
      await harness.animate(tester, count: 1, shadows: const [Shadow(blurRadius: 6)], childFor: (_) => fixture.value);
      expect((harness.property('nativeTextActive'), harness.property('shadowAtlasReady')), (false, true));
    });
  }

  testWidgets('when a shadow blur is below six, it should retain its exact rendering', (tester) async {
    final harness = ContourShadowAtlasTestHarness();
    await harness.animate(tester, shadows: const [Shadow(color: Color(0x33000000), blurRadius: 5.9)]);
    expect((harness.property('shadowAtlasReady'), harness.property('shadowAtlasBuildCount')), (false, 0));
  });

  testWidgets('when a shadow uses display P3, it should retain its exact color rendering', (tester) async {
    final harness = ContourShadowAtlasTestHarness();
    await harness.animate(
      tester,
      shadows: const [
        Shadow(
          color: Color.from(alpha: .2, red: 1, green: 0, blue: 0, colorSpace: ui.ColorSpace.displayP3),
          blurRadius: 6,
        ),
      ],
    );
    expect((harness.property('shadowAtlasReady'), harness.property('shadowAtlasBuildCount')), (false, 0));
  });
}
