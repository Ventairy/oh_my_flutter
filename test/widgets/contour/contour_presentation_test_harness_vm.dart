import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import 'contour_composite_capture_test_adapter.dart';
import 'contour_presentation_test_binding.dart';
import 'contour_test_painter.dart';

void main() {
  final binding = ContourPresentationTestBinding();
  final key = GlobalKey();
  late ContourCompositeCaptureTestAdapter adapter;
  final calls = <({int id, int width, int height})>[];
  var paused = false;

  void reply(int index) => adapter.complete(calls[index].id);

  Widget tree({bool knownBox = false, bool prepareWhenHidden = false, double amount = 3.5, Widget? source}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Contour(
            key: key,
            prepareWhenHidden: prepareWhenHidden,
            amount: amount,
            color: const Color(0xFFFFFFFF),
            child:
                source ??
                SizedBox(
                  width: 20,
                  height: 16,
                  child: ColoredBox(color: knownBox ? const Color(0xFF1278AB) : const Color(0x801278AB)),
                ),
          ),
        ),
      );

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Object? receipt() => ContourPresentationTestHarness.currentMainPresentation(
    renderObject: key.currentContext!.findRenderObject()!,
    frameNumber: binding.platformDispatcher.frameData.frameNumber,
  );

  Object? sourceLayer() => ContourPresentationTestHarness.currentSourceLayer(
    renderObject: key.currentContext!.findRenderObject()!,
    frameNumber: binding.platformDispatcher.frameData.frameNumber,
  );

  setUp(() {
    calls.clear();
    paused = false;
    binding.failPictures = false;
    adapter = ContourCompositeCaptureTestAdapter.test(
      onCapture: (request) {
        calls.add((id: request.id, width: request.width, height: request.height));
        if (!paused) scheduleMicrotask(() => reply(calls.length - 1));
      },
    );
    ContourCompositeSource.testOverride = adapter;
  });
  tearDown(() async {
    binding.failPictures = false;
    await adapter.dispose();
    ContourCompositeSource.testOverride = null;
  });

  testWidgets(
    'when an empty source has a current accepted carrier, it should expose the source without certifying ink',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        tree(
          source: const CustomPaint(size: Size(20, 16), painter: ContourTestPainter(empty: true)),
        ),
      );
      await frames(tester);
      expect((calls.length, receipt() != null, sourceLayer() != null), (1, true, true));
    },
  );

  testWidgets('when a replacement source is pending, it should not expose an earlier cached source', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    paused = true;
    await tester.pumpWidget(tree());
    await frames(tester);
    expect(sourceLayer(), isNull);
  });

  testWidgets('when a synchronous source paints directly, it should not expose a captured source', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree(knownBox: true));
    expect(sourceLayer(), isNull);
  });

  testWidgets('when a native decoration is emitted in MAIN, it should qualify the decoration and live foreground', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    final r = ContourPresentationTestHarness.currentMainPresentation(
      renderObject: key.currentContext!.findRenderObject()!,
      frameNumber: binding.platformDispatcher.frameData.frameNumber,
    );
    expect((r?.liveForegroundSubmitted, r?.knownBoxDirect), (true, false));
  });

  testWidgets('when a synchronous known box is emitted in MAIN, it should qualify its decoration and live foreground', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree(knownBox: true));
    final r = ContourPresentationTestHarness.currentMainPresentation(
      renderObject: key.currentContext!.findRenderObject()!,
      frameNumber: binding.platformDispatcher.frameData.frameNumber,
    );
    expect(
      (calls.length, r?.liveForegroundSubmitted, r?.knownBoxDirect),
      (0, true, true),
    );
  });

  testWidgets('when a native reply is ready before its next MAIN emission, it should not qualify from readiness', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    paused = true;
    await tester.pumpWidget(tree());
    await frames(tester);
    reply(0);
    await tester.idle();
    expect(receipt(), isNull);
  });

  testWidgets('when the actual view DPR changes after a valid emission, it should reject the old receipt immediately', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    tester.view.devicePixelRatio = 3;
    expect(receipt(), isNull);
  });

  testWidgets(
    'when style invalidates the configuration and its replacement is pending, it should reject the old receipt',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(tree());
      await frames(tester);
      paused = true;
      await tester.pumpWidget(tree(amount: 5));
      expect(receipt(), isNull);
    },
  );

  testWidgets('when addPicture throws before emission, it should not publish a MAIN receipt', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    paused = true;
    await tester.pumpWidget(tree());
    await frames(tester);
    reply(0);
    await tester.idle();
    binding.failPictures = true;
    await tester.pump();
    final error = tester.takeException();
    binding.failPictures = false;
    expect((error?.toString(), receipt()), ('Bad state: test addPicture failed before emission', null));
  });

  testWidgets(
    'when only a source prepared offstage is ready, it should not qualify hidden work as MAIN',
    (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(Offstage(child: tree(prepareWhenHidden: true)));
      await frames(tester);
      final ready = key.currentContext!
          .findRenderObject()!
          .toDiagnosticsNode()
          .getProperties()
          .singleWhere((p) => p.name == 'compositeReady')
          .value;
      expect((calls.length, ready, receipt()), (1, true, null));
    },
  );

  testWidgets('when a known-box layer is retained in a later MAIN frame, it should keep its current receipt', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree(knownBox: true));
    final before = receipt();
    final beforeFrame = binding.platformDispatcher.frameData.frameNumber;
    binding.scheduleFrame();
    await tester.pump();
    expect(
      (before != null, binding.platformDispatcher.frameData.frameNumber > beforeFrame, receipt() != null),
      (true, true, true),
    );
  });
}
