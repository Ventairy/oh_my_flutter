@TestOn('vm')
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import 'contour_composite_capture_test_adapter.dart';
import 'contour_solid_test_painter.dart';

void main() {
  late ContourCompositeCaptureTestAdapter adapter;
  final calls = <({int id, int width, int height, ui.Picture carrier})>[];

  Widget scene() => const Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(devicePixelRatio: 2),
      child: RepaintBoundary(
        child: Center(
          child: Contour(
            color: Color(0xFFFFFFFF),
            amount: 3,
            child: CustomPaint(size: Size.square(20), painter: ContourSolidTestPainter()),
          ),
        ),
      ),
    ),
  );

  Future<void> frames(WidgetTester tester) async {
    for (var index = 0; index < 6; index++) {
      await tester.pump();
    }
  }

  void reply() => adapter.complete(calls.last.id);

  setUp(() {
    calls.clear();
    adapter = ContourCompositeCaptureTestAdapter.test(
      onCapture: (request) {
        calls.add((id: request.id, width: request.width, height: request.height, carrier: request.picture));
      },
    );
    ContourCompositeSource.testOverride = adapter;
  });

  tearDown(() async {
    await adapter.dispose();
    ContourCompositeSource.testOverride = null;
  });

  testWidgets('when view metrics retain the same density, it should keep the current decoration before relayout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(scene());
    await frames(tester);
    reply();
    await frames(tester);
    final carrier = calls.single.carrier;
    tester.view.physicalSize = const Size(900, 650);
    expect((carrier.debugDisposed, calls.length), (false, 1));
  });

  testWidgets('when density changes during a pending capture, it should retire that carrier before any reply', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(scene());
    await frames(tester);
    final carrier = calls.single.carrier;
    tester.view.devicePixelRatio = 3;
    await tester.idle();
    expect((adapter.pendingCount, carrier.debugDisposed), (0, true));
  });

  testWidgets('when the last owner detaches and a new owner mounts, it should observe the new owning view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(scene());
    await frames(tester);
    reply();
    await frames(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(scene());
    await frames(tester);
    reply();
    await frames(tester);
    final carrier = calls.last.carrier;
    tester.view.devicePixelRatio = 3;
    expect(carrier.debugDisposed, true);
  });
}
