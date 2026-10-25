import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_solid_test_painter.dart';
import 'contour_test_harness.dart';

void main() {
  testWidgets('when decoration color and amount change, it should replace the picture and reuse the source shape', (
    tester,
  ) async {
    final harness = ContourTestHarness();
    const child = SizedBox.square(
      dimension: 40,
      child: CustomPaint(painter: ContourSolidTestPainter(color: Color(0xff0000ff))),
    );
    await harness.mount(tester, amount: 4, child: child);
    final before = await harness.pixels(tester);
    final captures = harness.captureCount;

    await harness.mount(tester, color: const Color(0xffff00ff), amount: 8, child: child);
    final after = await harness.pixels(tester);

    expect(
      [
        captures,
        harness.captureCount,
        ContourTestHarness.pixel(before, 24, 50),
        ContourTestHarness.pixel(after, 24, 50),
        ContourTestHarness.pixel(after, 35, 50),
        tester.binding.hasScheduledFrame,
      ],
      [
        1,
        1,
        [0, 0, 0, 0],
        [255, 0, 255, 255],
        [0, 0, 255, 255],
        false,
      ],
    );
  });
}
