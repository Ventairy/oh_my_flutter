import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';
import 'package:oh_my_flutter/src/widgets/motion/motion.dart';

import 'contour_composite_capture_test_adapter.dart';
import 'contour_test_harness.dart';

void main() {
  late ContourCompositeCaptureTestAdapter adapter;
  late ContourController controller;
  final key = GlobalKey();
  final calls = <({int id, int width, int height, double outputRatio, ui.Picture carrier, ui.Picture source})>[];
  final replied = <int>{};
  final sourceColor = ValueNotifier(const Color(0x801278AB));
  final translation = ValueNotifier(Offset.zero);
  final scale = ValueNotifier<double>(1);
  var paused = false;
  var declined = false;

  void reply(int index) {
    if (!replied.add(index)) return;
    final call = calls[index];
    if (declined) {
      adapter.decline(call.id);
    } else {
      adapter.complete(call.id);
    }
  }

  Widget tree({
    double density = 2,
    double amount = 3.5,
    Size sourceSize = const Size(20, 16),
    Color contourColor = const Color(0xFFFFFFFF),
    List<Shadow> shadows = const [Shadow(color: Color(0x80000000), blurRadius: 2, offset: Offset(1, 2))],
    VoidCallback? onTap,
    Widget Function(Widget child)? wrap,
  }) {
    final contour = Contour(
      key: key,
      controller: controller,
      color: contourColor,
      amount: amount,
      shadows: shadows,
      child: GestureDetector(
        onTap: onTap,
        child: RepaintBoundary(
          child: ValueListenableBuilder<Color>(
            valueListenable: sourceColor,
            builder: (_, color, _) => SizedBox(
              width: sourceSize.width,
              height: sourceSize.height,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
    final child = wrap == null ? contour : wrap(contour);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(devicePixelRatio: density),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: .25, top: .375),
            child: ValueListenableBuilder<Offset>(
              valueListenable: translation,
              builder: (_, offset, _) => Transform.translate(
                offset: offset,
                child: ValueListenableBuilder<double>(
                  valueListenable: scale,
                  builder: (_, factor, _) => Transform.scale(scale: factor, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Object? property(String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .singleWhere((p) => p.name == name)
      .value;
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.idle();
    for (var i = 0; i < 200 && (ContourProcessorTestHarness.prepared || ContourProcessorTestHarness.stopping); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
  }

  setUp(() {
    calls.clear();
    replied.clear();
    paused = false;
    declined = false;
    sourceColor.value = const Color(0x801278AB);
    translation.value = Offset.zero;
    scale.value = 1;
    controller = ContourController();
    adapter = ContourCompositeCaptureTestAdapter.test(
      onCapture: (request) {
        calls.add((
          id: request.id,
          width: request.width,
          height: request.height,
          outputRatio: request.outputRatio,
          carrier: request.picture,
          source: request.source,
        ));
        if (!paused) scheduleMicrotask(() => reply(calls.length - 1));
      },
    );
    ContourCompositeSource.testOverride = adapter;
  });
  tearDown(() async {
    await adapter.dispose();
    ContourCompositeSource.testOverride = null;
    controller.dispose();
  });

  testWidgets('when native composition is available, it should prepare without stock captures or processor startup', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    final actual = (
      calls.length,
      controller.isReady,
      property('compositeReady'),
      property('captureCount'),
      ContourProcessorTestHarness.prepared,
      calls.every((call) => call.source.debugDisposed),
    );
    await cleanup(tester);
    expect(actual, (1, true, true, 0, false, true));
  });

  for (final amount in [0.0, .1]) {
    testWidgets(
      'when the physical amount is below native precision at $amount, it should use stock without a native source job',
      (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(tree(amount: amount));
        await ContourTestHarness.settle(tester);
        final actual = (calls.length, controller.isReady);
        await cleanup(tester);
        expect(actual, (0, true));
      },
    );
  }

  testWidgets('when source pixels exactly meet admission, it should submit within the native source limit', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree(density: 3, sourceSize: const Size.square(169)));
    await frames(tester);
    final actual = calls.map((call) => (call.width, call.height)).toList();
    await cleanup(tester);
    expect(actual, [(512, 512)]);
  });

  testWidgets('when source pixels exceed admission, it should use stock without a native source job', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree(density: 3, sourceSize: const Size(170, 169)));
    await ContourTestHarness.settle(tester);
    final actual = (calls.length, controller.isReady);
    await cleanup(tester);
    expect(actual, (0, true));
  });

  testWidgets(
    'when a rotated label is held by Motion, it should capture the resting frame once and reuse it through the pop',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      final motion = MotionController();
      await tester.pumpWidget(
        tree(
          sourceSize: const Size(150, 27),
          wrap: (child) => Transform.rotate(
            angle: .72,
            child: Motion(
              controller: motion,
              startup: MotionStartup.hold,
              effect: const PopMotionEffect(scale: .65, duration: Duration(milliseconds: 100)),
              child: child,
            ),
          ),
        ),
      );
      controller.prepare();
      await frames(tester);
      final first = calls.single.carrier;
      final pixels = calls.single.width * calls.single.height;
      motion.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await frames(tester);
      final actual = (
        calls.length,
        property('compositeReady'),
        pixels > 65536 && pixels <= 262144,
        first.debugDisposed,
      );
      await cleanup(tester);
      expect(actual, (1, true, true, false));
    },
  );

  testWidgets(
    'when a rotated native source is declined, it should continue through ordinary stock geometry',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      declined = true;
      await tester.pumpWidget(tree(wrap: (child) => Transform.rotate(angle: .72, child: child)));
      await ContourTestHarness.settle(tester);
      final actual = (
        calls.length,
        property('compositeReady'),
        (property('captureCount')! as int) > 0,
        controller.isReady,
      );
      await cleanup(tester);
      expect(actual, (1, false, true, true));
    },
  );

  testWidgets('when a static resting scale makes a thin amount visible, it should use the scaled native precision', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree(amount: .1, wrap: (child) => Transform.scale(scale: 4, child: child)));
    await frames(tester);
    final actual = (calls.length, property('compositeReady'));
    await cleanup(tester);
    expect(actual, (1, true));
  });

  testWidgets('when a nested source repaints, it should dispose the old composite and accept its replacement', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    final old = calls.single.carrier;
    paused = true;
    sourceColor.value = const Color(0x8022AA33);
    await frames(tester);
    final before = (calls.length, old.debugDisposed, property('compositeReady'));
    reply(calls.length - 1);
    await frames(tester);
    final actual = (before, property('compositeReady'), calls.last.carrier.debugDisposed);
    await cleanup(tester);
    expect(actual, ((2, true, false), true, false));
  });

  testWidgets(
    'when an owner detaches while native work is pending, it should release its pending carrier immediately',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      paused = true;
      await tester.pumpWidget(tree());
      await frames(tester);
      final old = calls.single.carrier;
      await cleanup(tester);
      reply(0);
      await tester.idle();
      expect((adapter.pendingCount, old.debugDisposed, ContourProcessorTestHarness.prepared), (0, true, false));
    },
  );

  testWidgets('when only a parent transform changes after adoption, it should reuse the same current composite', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    final old = calls.single.carrier;
    for (final factor in [.6, 1.1, 1.0]) {
      scale.value = factor;
      translation.value += const Offset(.375, 1.125);
      await frames(tester);
    }
    final actual = (calls.length, property('compositeReady'), old.debugDisposed);
    await cleanup(tester);
    expect(actual, (1, true, false));
  });

  for (final pending in [false, true]) {
    testWidgets(
      'when decoration style changes while a composite is ${pending ? 'pending' : 'ready'}, it should reuse stock geometry for later style changes',
      (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        paused = pending;
        await tester.pumpWidget(tree());
        await frames(tester);
        final old = calls.single.carrier;
        await tester.pumpWidget(tree(amount: 5));
        await ContourTestHarness.settle(tester);
        final captures = property('captureCount')! as int;
        for (final amount in [6.0, 7.0, 8.0]) {
          await tester.pumpWidget(tree(amount: amount, contourColor: const Color(0xFF998877), shadows: const []));
          await ContourTestHarness.settle(tester);
        }
        reply(0);
        await frames(tester);
        final actual = (
          calls.length,
          old.debugDisposed,
          property('compositeReady'),
          captures > 0,
          property('captureCount') == captures,
          controller.isReady,
        );
        await cleanup(tester);
        expect(actual, (1, true, false, true, true, true));
      },
    );
  }

  testWidgets('when source content changes after style fallback, it should try native composition for the new source', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    await tester.pumpWidget(tree(amount: 5));
    await ContourTestHarness.settle(tester);
    final captures = property('captureCount');
    sourceColor.value = const Color(0x8022AA33);
    await frames(tester);
    final actual = (calls.length, property('compositeReady'), property('captureCount') == captures);
    await cleanup(tester);
    expect(actual, (2, true, true));
  });

  testWidgets('when density changes after style fallback, it should try native composition at the new density', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(tree());
    await frames(tester);
    await tester.pumpWidget(tree(amount: 5));
    await ContourTestHarness.settle(tester);
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(tree(density: 3, amount: 5));
    await frames(tester);
    final actual = (calls.length, property('compositeReady'), calls.last.outputRatio);
    await cleanup(tester);
    expect(actual, (2, true, 3));
  });

  testWidgets(
    'when the retained real view density changes with fixed MediaQuery, it should discard the old composite',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(SizedBox.square(dimension: 100, child: RepaintBoundary(child: tree())));
      await frames(tester);
      final old = calls.single.carrier;
      tester.view.devicePixelRatio = 3;
      await frames(tester);
      final actual = (property('compositeReady'), old.debugDisposed);
      await cleanup(tester);
      expect(actual, (false, true));
    },
  );

  testWidgets('when the retained real view density changes before a pending reply, it should reject that old carrier', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    paused = true;
    await tester.pumpWidget(SizedBox.square(dimension: 100, child: RepaintBoundary(child: tree())));
    await frames(tester);
    final old = calls.single.carrier;
    tester.view.devicePixelRatio = 3;
    reply(0);
    await tester.idle();
    await frames(tester);
    final actual = (property('compositeReady'), old.debugDisposed);
    await cleanup(tester);
    expect(actual, (false, true));
  });

  testWidgets('when native composition declines a source, it should use the unchanged stock capture fallback', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(adapter.dispose);
    adapter = ContourCompositeCaptureTestAdapter.test(onCapture: (request) => adapter.decline(request.id));
    ContourCompositeSource.testOverride = adapter;
    await tester.pumpWidget(tree());
    await ContourTestHarness.settle(tester);
    final actual = (property('compositeReady'), (property('captureCount')! as int) > 0, controller.isReady);
    await cleanup(tester);
    expect(actual, (false, true, true));
  });

  testWidgets('when a composite is current, it should preserve live child interaction', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(tree(onTap: () => taps++));
    await frames(tester);
    await tester.tap(find.byType(ColoredBox));
    await cleanup(tester);
    expect(taps, 1);
  });
  {
    testWidgets(
      'when a known box is synchronous, it should keep its first-frame path without native jobs',
      (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Contour(
                key: key,
                controller: controller,
                color: const Color(0xFFFFFFFF),
                amount: 3.5,
                child: const SizedBox.square(dimension: 40, child: ColoredBox(color: Color(0xFF328BCB))),
              ),
            ),
          ),
        );
        final actual = (
          calls.length,
          controller.isReady,
          property('declaredPathActive'),
          property('captureCount'),
          ContourProcessorTestHarness.prepared,
        );
        await cleanup(tester);
        expect(actual, (0, true, true, 0, false));
      },
    );
  }
}
