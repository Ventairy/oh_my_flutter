import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_geometry_image_painter.dart';
import 'contour_geometry_test_painter.dart';
import 'contour_test_harness.dart';

void main() {
  Object? diagnostic(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((property) => property.name == name)
      .value;

  Widget scene(GlobalKey key, GlobalKey boundary, Widget child) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 1),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: boundary,
          child: SizedBox.square(
            dimension: 300,
            child: Center(
              child: Contour(key: key, color: const Color(0xFF0000FF), amount: 3, child: child),
            ),
          ),
        ),
      ),
    ),
  );

  const dense = SizedBox.square(dimension: 256, child: CustomPaint(painter: ContourGeometryTestPainter()));

  Future<List<int>> pixel(WidgetTester tester, GlobalKey boundary, int x, int y) async {
    final image = await tester.runAsync(
      () => (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(),
    );
    try {
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      final offset = (y * 300 + x) * 4;
      return bytes!.buffer.asUint8List(offset, 4).toList();
    } finally {
      image!.dispose();
    }
  }

  testWidgets('when dense artwork exceeds geometry capacity, it should retry within the shared reservation', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(scene(key, GlobalKey(), dense));
    await ContourTestHarness.settle(tester);
    final budget = ContourWorkBudget.shared;
    expect(
      (
        (diagnostic(key, 'geometryCapacityExceededCount')! as int) > 0,
        diagnostic(key, 'contourReady'),
        budget.activeBytes,
        budget.peakBytes <= budget.maxBytes,
      ),
      (true, true, 0, true),
    );
  });

  testWidgets('when dense artwork is resampled, it should preserve the live opaque child pixels', (tester) async {
    final key = GlobalKey();
    final boundary = GlobalKey();
    await tester.pumpWidget(scene(key, boundary, dense));
    await ContourTestHarness.settle(tester);
    expect(await pixel(tester, boundary, 22, 22), [255, 0, 0, 255]);
  });

  testWidgets('when dense artwork replaces a larger source, it should discard the former backing', (tester) async {
    final key = GlobalKey();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      scene(key, boundary, const SizedBox.square(dimension: 280, child: ColoredBox(color: Color(0xFFFF0000)))),
    );
    await ContourTestHarness.settle(tester);
    await tester.pumpWidget(scene(key, boundary, dense));
    await ContourTestHarness.settle(tester);
    expect(await pixel(tester, boundary, 15, 150), [0, 0, 0, 0]);
  });
  testWidgets(
    'when density retries exhaust geometry capacity, it should keep the child without repeating obsolete work',
    (tester) async {
      const side = 256;
      final rgba = Uint8List(side * side * 4);
      for (var y = 0; y < side; y++) {
        for (var x = y % 2; x < side; x += 2) {
          final offset = (y * side + x) * 4;
          rgba[offset] = 255;
          rgba[offset + 3] = 255;
        }
      }
      final image = await tester.runAsync(() {
        final ready = Completer<ui.Image>();
        ui.decodeImageFromPixels(rgba, side, side, ui.PixelFormat.rgba8888, ready.complete);
        return ready.future;
      });
      final key = GlobalKey();
      final boundary = GlobalKey();
      Widget enlarged(double amount) => MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox.square(
                dimension: 300,
                child: OverflowBox(
                  minWidth: 4000,
                  maxWidth: 4000,
                  minHeight: 4000,
                  maxHeight: 4000,
                  child: Contour(
                    key: key,
                    color: const Color(0xFF0000FF),
                    amount: amount,
                    child: CustomPaint(size: const Size.square(4000), painter: ContourGeometryImagePainter(image!)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      try {
        await tester.pumpWidget(enlarged(3));
        await ContourTestHarness.settle(tester);
        final captures = diagnostic(key, 'captureCount');
        final status = diagnostic(key, 'geometryCapacityExceeded');
        await tester.pumpWidget(enlarged(8));
        await ContourTestHarness.settle(tester);
        expect(
          [
            status,
            diagnostic(key, 'contourReady'),
            diagnostic(key, 'captureCount') == captures,
            diagnostic(key, 'geometryCapacityExceededCount'),
            ContourWorkBudget.shared.activeBytes,
            ContourWorkBudget.shared.peakBytes <= ContourWorkBudget.shared.maxBytes,
            await pixel(tester, boundary, 150, 150),
          ],
          [
            true,
            false,
            true,
            4,
            0,
            true,
            [255, 0, 0, 255],
          ],
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        image!.dispose();
      }
    },
  );
}
