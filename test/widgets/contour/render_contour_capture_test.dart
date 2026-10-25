import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_test_harness.dart';

void main() {
  testWidgets('when content paints beyond its layout bounds, it should include the reported overflow', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 4,
      child: Transform.translate(
        offset: const Offset(10, 0),
        child: const SizedBox.square(dimension: 40, child: ColoredBox(color: Colors.red)),
      ),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 82, 50), [255, 255, 255, 255]);
  });
}
