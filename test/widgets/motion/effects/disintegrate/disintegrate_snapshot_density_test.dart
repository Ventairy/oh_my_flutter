import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'configured_disintegrate_effect.dart';
import 'disintegrate_test_harness.dart';

void main() {
  for (final ratio in [1.0, 2.0, 3.0]) {
    testWidgets('when the badge fits the budget at ${ratio}x, it should capture it at display density', (
      tester,
    ) async {
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = DisintegrateTestHarness(tester, native: true);
      await harness.mount(
        effect: const DisintegrateMotionEffect(direction: Offset(1, -1)),
        child: const ColoredBox(color: Color(0x80808080), child: SizedBox(width: 200, height: 48)),
      );
      await harness.start();
      final arguments =
          harness.calls.singleWhere((call) => call.method == 'prepare').arguments! as Map<Object?, Object?>;

      expect(
        [
          arguments['width'],
          arguments['height'],
          arguments['viewportWidth'],
          arguments['originX'],
          arguments['minimumCellSize'],
        ],
        [200 * ratio, 48 * ratio, 260 * ratio, 30 * ratio, closeTo(2.2 * ratio, 0.001)],
      );
    });
  }

  for (final (sourceSize, maxDimension) in [(const Size(800, 600), false), (const Size(2047, 8), true)]) {
    testWidgets('when a capture would exceed the raster budget, it should fit $sourceSize and its probe', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = sourceSize * 3;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final harness = DisintegrateTestHarness(tester, native: true);
      await harness.mount(
        effect: DisintegrateMotionEffect(direction: maxDimension ? Offset.zero : const Offset(1, -1)),
        canvasSize: sourceSize,
        child: SizedBox.fromSize(size: sourceSize),
      );
      await harness.start();
      final arguments =
          harness.calls.singleWhere((call) => call.method == 'prepare').arguments! as Map<Object?, Object?>;
      final width = arguments['viewportWidth']! as int;
      final height = (arguments['viewportHeight']! as int) + 1;

      expect(
        [width, height, width * height],
        [
          if (maxDimension) 2048 else inInclusiveRange(800, 810),
          lessThanOrEqualTo(2048),
          if (maxDimension) lessThanOrEqualTo(524288) else inInclusiveRange(522000, 524288),
        ],
      );
    });
  }

  testWidgets('when the Dart fallback replaces an intact translucent badge, it should preserve its pixels at 3x', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(
      effect: const ConfiguredDisintegrateEffect(progress: 0),
      child: const DecoratedBox(
        decoration: ShapeDecoration(color: Color(0x808050FF), shape: StadiumBorder()),
        child: SizedBox(width: 200, height: 48),
      ),
    );
    final livePixels = await harness.pixels(pixelRatio: 3);
    await harness.start();
    final snapshotPixels = await harness.pixels(pixelRatio: 3);
    var largestDifference = 0;
    for (var channel = 0; channel < livePixels.length; channel++) {
      largestDifference = math.max(largestDifference, (livePixels[channel] - snapshotPixels[channel]).abs());
    }

    // Capturing and compositing premultiplied color can round antialiased edges.
    expect(largestDifference, lessThanOrEqualTo(4));
  });
}
