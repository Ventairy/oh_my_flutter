import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour/contour_test_harness.dart';
import 'contour/contour_test_painter.dart';

void main() {
  testWidgets('when amount is zero, it should preserve an enclosed transparent center', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 50), [0, 0, 0, 0]);
  });

  testWidgets('when the child has an open center, it should preserve its transparency', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(open: true)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 50), [0, 0, 0, 0]);
  });

  testWidgets('when amount reaches an inner edge, it should shrink the transparent center', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 4,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 42, 50), [255, 255, 255, 255]);
  });

  testWidgets('when expanded inner edges have not met, it should preserve the remaining center', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 4,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 50), [0, 0, 0, 0]);
  });

  testWidgets('when expanded inner edges meet, it should close the transparent center', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 12,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 50), [255, 255, 255, 255]);
  });

  testWidgets('when amount is positive, it should paint outside the child', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 6,
      child: const SizedBox.square(dimension: 40, child: ColoredBox(color: Colors.red)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 26, 50), [255, 255, 255, 255]);
  });

  testWidgets('when amount is positive, it should preserve the child layout size', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(tester, amount: 6, child: const SizedBox.square(dimension: 40));
    expect(tester.getSize(find.byKey(harness.backdropKey)), const Size.square(40));
  });

  testWidgets('when the child paints nothing, it should leave the canvas transparent', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(tester, child: const SizedBox.square(dimension: 40));
    expect((await harness.pixels(tester)).any((byte) => byte != 0), isFalse);
  });

  testWidgets('when no shadows are configured, it should not paint beyond its amount', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const SizedBox.square(dimension: 40, child: ColoredBox(color: Colors.red)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 25, 50), [0, 0, 0, 0]);
  });

  testWidgets('when amount is negative, it should diagnose the contract violation', (tester) async {
    expect(() => Contour(color: Colors.white, amount: -1, child: const SizedBox()), throwsAssertionError);
  });
}
