import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_non_rasterizable_test_source.dart';
import 'contour_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  Widget scene({required ContourController controller, Widget? child, Color color = const Color(0xFFFFFFFF)}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Contour(
            controller: controller,
            color: color,
            amount: 3,
            child:
                child ??
                const SizedBox.square(
                  dimension: 20,
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFFF0000))),
                ),
          ),
        ),
      );

  test('when no contour is attached, it should remain unready', () {
    final controller = ContourController();
    addTearDown(controller.dispose);

    expect(controller.isReady, false);
  });

  test('when preparation is requested without an attached contour, it should do nothing', () {
    final controller = ContourController();
    addTearDown(controller.dispose);

    expect(controller.prepare, returnsNormally);
  });

  test('when preparation is requested after disposal, it should do nothing', () {
    final controller = ContourController()..dispose();

    expect(controller.prepare, returnsNormally);
  });

  testWidgets('when preparation is requested for attached content, it should reset and restore readiness', (
    tester,
  ) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(scene(controller: controller));
    controller.prepare();
    final readyAfterRequest = controller.isReady;
    await tester.pump();

    expect((readyAfterRequest, controller.isReady), (false, true));
  });

  testWidgets('when hidden nested artwork changes, it should prepare its current backing before reveal', (
    tester,
  ) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    final open = ValueNotifier(false);
    final visible = ValueNotifier(false);
    addTearDown(open.dispose);
    addTearDown(visible.dispose);
    final harness = ContourTestHarness();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: harness.boundaryKey,
              child: SizedBox.square(
                dimension: 100,
                child: ValueListenableBuilder(
                  valueListenable: visible,
                  builder: (context, value, child) => Opacity(opacity: value ? 1 : 0, child: child),
                  child: Center(
                    child: Contour(
                      controller: controller,
                      prepareWhenHidden: true,
                      color: const Color(0xFFFFFFFF),
                      amount: 3,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: const Size.square(60),
                          painter: ContourTestPainter(isOpen: open),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    open.value = true;
    controller.prepare();
    await ContourTestHarness.settle(tester);
    visible.value = true;
    await tester.pump();
    final pixels = await harness.pixels(tester);

    expect(
      [ContourTestHarness.pixel(pixels, 70, 50), ContourTestHarness.pixel(pixels, 18, 50)],
      [
        [0, 0, 0, 0],
        [255, 255, 255, 255],
      ],
    );
  });

  testWidgets('when preparation is requested repeatedly before a frame, it should combine readiness notifications', (
    tester,
  ) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    final events = <bool>[];
    controller.addListener(() => events.add(controller.isReady));
    await tester.pumpWidget(scene(controller: controller));
    controller
      ..prepare()
      ..prepare();
    await tester.idle();
    await tester.pump();

    expect(events, [true, false, true]);
  });

  testWidgets('when a known shape is prepared, it should notify readiness once', (tester) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    final events = <bool>[];
    controller.addListener(() => events.add(controller.isReady));
    await tester.pumpWidget(scene(controller: controller));
    await tester.pump();

    expect(events, [true]);
  });

  testWidgets('when decoration is transparent, it should become ready without waiting for a backing', (tester) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(scene(controller: controller, color: const Color(0x00000000)));

    expect(controller.isReady, true);
  });

  testWidgets('when preparation cannot capture the child, it should become ready for fallback presentation', (
    tester,
  ) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(scene(controller: controller, child: const ContourNonRasterizableTestSource()));
    await ContourTestHarness.settle(tester);

    expect(controller.isReady, true);
  });

  testWidgets('when readiness resolves during a frame, it should notify listeners after frame callbacks finish', (
    tester,
  ) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    final phases = <SchedulerPhase>[];
    controller.addListener(() => phases.add(SchedulerBinding.instance.schedulerPhase));
    await tester.pumpWidget(scene(controller: controller));

    expect(phases, [SchedulerPhase.idle]);
  });

  testWidgets('when a ready contour detaches, it should notify that its content is no longer ready', (tester) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    final events = <bool>[];
    controller.addListener(() => events.add(controller.isReady));
    await tester.pumpWidget(scene(controller: controller));
    await tester.pumpWidget(const SizedBox.shrink());

    expect(events, [true, false]);
  });

  testWidgets('when its controller is replaced, it should move readiness to the new controller', (tester) async {
    final previous = ContourController();
    final replacement = ContourController();
    addTearDown(previous.dispose);
    addTearDown(replacement.dispose);
    await tester.pumpWidget(scene(controller: previous));
    await tester.pumpWidget(scene(controller: replacement));

    expect((previous.isReady, replacement.isReady), (false, true));
  });

  testWidgets('when equivalent content rebuilds, it should not send redundant readiness notifications', (tester) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    final events = <bool>[];
    controller.addListener(() => events.add(controller.isReady));
    await tester.pumpWidget(scene(controller: controller));
    await tester.pumpWidget(scene(controller: controller));
    await tester.pump();

    expect(events, [true]);
  });

  testWidgets('when a ready notification is queued before disposal, it should cancel that notification', (
    tester,
  ) async {
    final controller = ContourController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    tester.binding.addPostFrameCallback((_) => controller.dispose());
    await tester.pumpWidget(scene(controller: controller));
    await tester.pumpWidget(const SizedBox.shrink());

    expect(notifications, 0);
  });

  testWidgets('when a disposed controller remains on a mounted contour, it should ignore later readiness updates', (
    tester,
  ) async {
    final controller = ContourController();
    await tester.pumpWidget(scene(controller: controller));
    controller.dispose();
    await tester.pumpWidget(scene(controller: controller, color: const Color(0x00000000)));
    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.isReady, false);
  });

  testWidgets('when two contours share a controller, it should diagnose the unsupported attachment', (tester) async {
    final controller = ContourController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: Contour(
                controller: controller,
                color: const Color(0x00000000),
                child: const SizedBox.square(dimension: 20),
              ),
            ),
            SizedBox.square(
              dimension: 20,
              child: Contour(
                controller: controller,
                color: const Color(0x00000000),
                child: const SizedBox.square(dimension: 20),
              ),
            ),
          ],
        ),
      ),
    );

    expect(
      tester.takeException(),
      isA<AssertionError>().having(
        (error) => error.message,
        'message',
        'A ContourController can attach to only one Contour at a time.',
      ),
    );
  });
}
