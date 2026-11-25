import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'configured_disintegrate_effect.dart';
import 'disintegrate_test_harness.dart';

void main() {
  testWidgets('when a stationary particle detaches, it should have a solid center and transparent corners', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 16;
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(
      canvasSize: const Size.square(4),
      child: const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox.square(dimension: 2)),
      effect: const ConfiguredDisintegrateEffect(progress: 0.15),
    );
    await harness.start();
    final pixels = await harness.pixels(pixelRatio: 16);
    const width = 64;
    var left = width;
    var right = -1;
    var top = width;
    var bottom = -1;
    for (var pixel = 0; pixel < pixels.length ~/ 4; pixel++) {
      if (pixels[pixel * 4 + 3] < 128) continue;
      left = math.min(left, pixel % width);
      right = math.max(right, pixel % width);
      top = math.min(top, pixel ~/ width);
      bottom = math.max(bottom, pixel ~/ width);
    }
    int alpha(int x, int y) => pixels[(y * width + x) * 4 + 3];
    final center = alpha((left + right) ~/ 2, (top + bottom) ~/ 2);
    expect(
      [center, alpha(left, top), alpha(right, top), alpha(left, bottom), alpha(right, bottom)],
      [greaterThan(180), 0, 0, 0, 0],
    );
  });
}
