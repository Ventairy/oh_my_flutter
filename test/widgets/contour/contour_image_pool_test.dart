import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_shadow_pool_test_harness.dart';
import 'contour_test_harness.dart';

void main() {
  for (final count in [20, 40]) {
    testWidgets('when $count equivalent contours settle, it should retain one shared shadow image', (tester) async {
      final harness = ContourShadowPoolTestHarness();
      await harness.mount(tester, count: count);
      expect(
        (harness.resourceIds(count).toSet().length, harness.resourceIds(count).contains(0)),
        (1, false),
        reason: '${harness.property("nativeTextStatus")} ${harness.resourceIds(count)}',
      );
    });
  }
  for (final count in [20, 40]) {
    testWidgets('when $count identical contours draw shared shadows, it should preserve every cell pixel', (
      tester,
    ) async {
      final harness = ContourShadowPoolTestHarness();
      await harness.mount(tester, count: count);
      final rgba = await harness.pixels(tester);
      expect(harness.mismatchedCells(rgba, count), 0);
    });
  }
  testWidgets('when many unique shadows exceed the budget, it should bound retained image pixels', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(
      tester,
      count: 40,
      pixelRatio: 2,
      shadowsFor: (index) => [
        Shadow(color: const Color(0x33000000), blurRadius: 50, offset: Offset(index.toDouble(), 2)),
      ],
    );
    final pixels = harness.property('shadowPoolPixels')! as int;
    final entries = harness.property('shadowPoolEntries')! as int;
    final ready = harness.resourceIds(40).where((id) => id != 0).length;
    expect((pixels <= 4 * 1024 * 1024, entries < 40, ready > 0), (true, true, true));
  });
  testWidgets(
    'when static and animated owners share the image pool, it should retain one resource for each image kind',
    (tester) async {
      final harness = ContourShadowPoolTestHarness();
      const shadows = [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))];
      await harness.mount(tester, count: 40, amount: 1, shadows: shadows);
      for (final amount in [2.0, 3.0, 4.0]) {
        await tester.pump(const Duration(milliseconds: 60));
        await harness.mount(
          tester,
          count: 40,
          amountFor: (index) => index < 20 ? amount : 1,
          shadows: shadows,
          settle: false,
        );
      }
      await ContourTestHarness.settle(tester);
      final atlasIds = [
        for (var index = 0; index < 20; index++) harness.property('shadowAtlasResourceId', index)! as int,
      ];
      final staticIds = harness.resourceIds(40).skip(20).toList();
      expect(
        (
          atlasIds.toSet().length,
          atlasIds.first > 0,
          staticIds.toSet().length,
          staticIds.first > 0,
          atlasIds.first != staticIds.first,
          harness.property('shadowPoolEntries'),
          (harness.property('shadowPoolPixels')! as int) <= 4 * 1024 * 1024,
        ),
        (1, true, 1, true, true, 2, true),
      );
    },
  );
}
