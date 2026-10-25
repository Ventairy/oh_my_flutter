import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_repaint_test_painter.dart';
import 'contour_solid_test_painter.dart';
import 'contour_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  testWidgets('when a nested boundary repaints, it should update the backing without a widget rebuild', (tester) async {
    final open = ValueNotifier(false);
    addTearDown(open.dispose);
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size.square(40),
          painter: ContourTestPainter(isOpen: open),
        ),
      ),
    );
    open.value = true;
    await tester.pump();
    await ContourTestHarness.settle(tester);
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 50), [0, 0, 0, 0]);
  });

  testWidgets('when the whole contour moves, it should reuse its captured shape', (tester) async {
    final harness = ContourTestHarness();
    const child = CustomPaint(size: Size.square(40), painter: ContourTestPainter());
    await harness.mount(tester, amount: 4, child: child);
    final captures = harness.captureCount;
    await harness.mount(tester, amount: 4, translation: const Offset(3, 2), child: child);
    expect(harness.captureCount, captures);
  });

  testWidgets('when only amount changes, it should reuse its captured shape', (tester) async {
    final harness = ContourTestHarness();
    const child = CustomPaint(size: Size.square(40), painter: ContourTestPainter());
    await harness.mount(tester, amount: 4, child: child);
    final captures = harness.captureCount;
    await harness.mount(tester, amount: 8, child: child);
    expect(harness.captureCount, captures);
  });

  testWidgets('when generation finishes, it should stop scheduling frames', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'when a nested boundary changes its painted source, it should retire both stale backdrops without a widget rebuild',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final open = ValueNotifier(false);
      addTearDown(open.dispose);
      final inner = ContourController();
      addTearDown(inner.dispose);
      final harness = ContourTestHarness();
      await harness.mount(
        tester,
        amount: 3,
        color: const Color(0xFF000000),
        child: Contour(
          controller: inner,
          color: const Color(0xFFFFFFFF),
          amount: 3,
          child: RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(40),
              painter: ContourRepaintTestPainter(open),
            ),
          ),
        ),
      );
      final before = ContourTestHarness.pixel(await harness.pixels(tester), 68, 50);
      open.value = true;
      await tester.pump();
      await ContourTestHarness.settle(tester);
      final after = ContourTestHarness.pixel(await harness.pixels(tester), 68, 50);
      final ready = harness.backdropKey.currentContext!
          .findRenderObject()!
          .toDiagnosticsNode()
          .getProperties()
          .firstWhere((property) => property.name == 'contourReady')
          .value;
      expect(
        [before, after, ready, inner.isReady],
        [
          [0, 0, 255, 255],
          [0, 0, 0, 0],
          true,
          true,
        ],
      );
    },
  );

  testWidgets(
    'when opacity separates nested contours, it should complete the outer stock fallback and reveal both backings',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final inner = ContourController();
      addTearDown(inner.dispose);
      final harness = ContourTestHarness();
      await harness.mount(
        tester,
        amount: 3,
        color: const Color(0xFF000000),
        child: Opacity(
          opacity: .8,
          child: Contour(
            controller: inner,
            color: const Color(0xFFFFFFFF),
            amount: 3,
            child: const CustomPaint(size: Size.square(20), painter: ContourSolidTestPainter()),
          ),
        ),
      );
      final ready = harness.backdropKey.currentContext!
          .findRenderObject()!
          .toDiagnosticsNode()
          .getProperties()
          .firstWhere((property) => property.name == 'contourReady')
          .value;
      expect((ready, inner.isReady), (true, true));
    },
  );
}
