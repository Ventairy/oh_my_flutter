@TestOn('vm')
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import '../contour_composite_capture_test_adapter.dart';
import '../contour_presentation_test_binding.dart';
import 'contour_composite_test_painter.dart';

void main() {
  final binding = ContourPresentationTestBinding();
  final key = GlobalKey();
  late ContourCompositeCaptureTestAdapter adapter;
  late ContourController controller;
  final calls = <({int id, int width, int height, ui.Picture carrier})>[];
  var paints = 0;

  void reply(int index) => adapter.complete(calls[index].id);

  Widget tree({bool prepareWhenHidden = false}) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Align(
        alignment: Alignment.topLeft,
        child: Contour(
          key: key,
          controller: controller,
          prepareWhenHidden: prepareWhenHidden,
          amount: 3.5,
          color: const Color(0xFFFFFFFF),
          child: CustomPaint(size: const Size(20, 16), painter: ContourCompositeTestPainter(() => paints++)),
        ),
      ),
    ),
  );

  Future<void> frames(WidgetTester tester) async {
    for (var index = 0; index < 6; index++) {
      await tester.pump();
    }
  }

  Object? property(String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .singleWhere((value) => value.name == name)
      .value;

  bool? receipt() {
    final value = ContourPresentationTestHarness.currentMainPresentation(
      renderObject: key.currentContext!.findRenderObject()!,
      frameNumber: binding.platformDispatcher.frameData.frameNumber,
    );
    return value?.liveForegroundSubmitted;
  }

  setUp(() {
    calls.clear();
    paints = 0;
    binding.failPictures = false;
    controller = ContourController();
    adapter = ContourCompositeCaptureTestAdapter.test(
      onCapture: (request) {
        calls.add((id: request.id, width: request.width, height: request.height, carrier: request.picture));
      },
    );
    ContourCompositeSource.testOverride = adapter;
  });
  tearDown(() async {
    binding.failPictures = false;
    await adapter.dispose();
    ContourCompositeSource.testOverride = null;
    controller.dispose();
  });

  testWidgets(
    'when a decoration-only result is adopted, it should report readiness with the original foreground live in MAIN',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(tree());
      await frames(tester);
      reply(0);
      await frames(tester);
      expect(
        (controller.isReady, property('compositeReady'), receipt()),
        (true, true, true),
      );
    },
  );

  testWidgets(
    'when the original foreground layer was retained before decoration, it should submit both without repainting the child',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(tree());
      await frames(tester);
      final before = paints;
      reply(0);
      await frames(tester);
      expect((paints == before, receipt()), (true, true));
    },
  );

  testWidgets(
    'when the retained real view density changes with fixed MediaQuery, it should dispose the old decoration carrier',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(SizedBox.square(dimension: 100, child: RepaintBoundary(child: tree())));
      await frames(tester);
      reply(0);
      await frames(tester);
      final old = calls.single.carrier;
      tester.view.devicePixelRatio = 3;
      await frames(tester);
      expect((property('compositeReady'), old.debugDisposed, receipt()), (false, true, null));
    },
  );

  testWidgets('when actual view density changes before a pending reply, it should reject that old decoration', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SizedBox.square(dimension: 100, child: RepaintBoundary(child: tree())));
    await frames(tester);
    final old = calls.single.carrier;
    tester.view.devicePixelRatio = 3;
    reply(0);
    await frames(tester);
    expect((property('compositeReady'), old.debugDisposed, receipt()), (false, true, null));
  });

  testWidgets(
    'when decoration emission throws, it should not publish a MAIN receipt merely because the child is live',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(tree());
      await frames(tester);
      reply(0);
      await tester.idle();
      binding.failPictures = true;
      await tester.pump();
      final error = tester.takeException();
      binding.failPictures = false;
      expect((error?.toString(), receipt()), ('Bad state: test addPicture failed before emission', null));
    },
  );

  testWidgets('when an offstage decoration finishes, it should remain absent from MAIN', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(Offstage(child: tree(prepareWhenHidden: true)));
    await frames(tester);
    reply(0);
    await frames(tester);
    expect((controller.isReady, property('compositeReady'), receipt()), (true, true, null));
  });
}
