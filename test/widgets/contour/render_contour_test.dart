import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_solid_test_painter.dart';
import 'contour_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  testWidgets('when all decoration is invisible, it should avoid capturing the child', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      color: Colors.transparent,
      shadows: const [Shadow(color: Colors.transparent, blurRadius: 12)],
      child: const SizedBox.square(
        dimension: 40,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    expect(harness.captureCount, 0);
  });

  testWidgets('when invisible decoration becomes visible, it should capture the child once', (tester) async {
    final harness = ContourTestHarness();
    const child = SizedBox.square(
      dimension: 40,
      child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
    );
    await harness.mount(tester, color: Colors.transparent, child: child);
    await harness.mount(tester, child: child);
    expect(harness.captureCount, 1);
  });

  testWidgets('when only a shadow is visible, it should prepare the backing geometry', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      color: Colors.transparent,
      shadows: const [Shadow(color: Colors.blue, offset: Offset(10, 0))],
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(circle: true)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 75, 50), [33, 150, 243, 255]);
  });

  testWidgets('when hidden artwork changes, it should defer its capture until decoration is visible', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const SizedBox.square(
        dimension: 40,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    await harness.mount(
      tester,
      color: Colors.transparent,
      child: const SizedBox.square(
        dimension: 20,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    expect(harness.captureCount, 1);
  });

  testWidgets('when changed hidden artwork becomes visible, it should contour the latest child', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const SizedBox.square(
        dimension: 40,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    const latest = SizedBox.square(
      dimension: 20,
      child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
    );
    await harness.mount(tester, color: Colors.transparent, child: latest);
    await harness.mount(tester, amount: 3, child: latest);
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 38, 50), [255, 255, 255, 255]);
  });

  testWidgets('when unchanged artwork becomes visible again, it should reuse the captured shape', (tester) async {
    final harness = ContourTestHarness();
    const child = SizedBox.square(
      dimension: 40,
      child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
    );
    await harness.mount(tester, child: child);
    await harness.mount(tester, color: Colors.transparent, child: child);
    await harness.mount(tester, child: child);
    expect(harness.captureCount, 1);
  });

  testWidgets('when a shadow has an offset, it should follow the backing rather than the layout rectangle', (
    tester,
  ) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      shadows: const [Shadow(color: Colors.blue, offset: Offset(10, 0))],
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(circle: true)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 75, 50), [33, 150, 243, 255]);
  });

  testWidgets('when the backing color is translucent, it should apply opacity only once', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      color: const Color(0x800000FF),
      amount: 6,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 26, 50), [0, 0, 128, 128]);
  });

  testWidgets('when an expanded child is tapped, it should retain its original interaction', (tester) async {
    final harness = ContourTestHarness();
    var taps = 0;
    await harness.mount(
      tester,
      amount: 10,
      child: GestureDetector(
        onTap: () => taps++,
        child: const SizedBox.square(
          dimension: 40,
          child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector));
    expect(taps, 1);
  });

  testWidgets('when the child provides a baseline, it should preserve that baseline', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(tester, amount: 6, child: const Text('O', style: TextStyle(fontSize: 30)));
    final child = tester.renderObject<RenderBox>(find.byType(RichText));
    final backdrop = tester.renderObject<RenderBox>(find.byKey(harness.backdropKey));
    expect(
      backdrop.getDryBaseline(BoxConstraints.tight(backdrop.size), TextBaseline.alphabetic),
      child.getDryBaseline(BoxConstraints.tight(child.size), TextBaseline.alphabetic),
    );
  });

  testWidgets('when the child is resized, it should replace the backing geometry', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const SizedBox.square(
        dimension: 40,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    await harness.mount(
      tester,
      amount: 3,
      child: const SizedBox.square(
        dimension: 20,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 32, 50), [0, 0, 0, 0]);
  });
}
