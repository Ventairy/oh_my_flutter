import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;
import 'package:oh_my_flutter/src/widgets/contour/contour.dart' show ContourProcessorTestHarness;
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_initial_frame_test_binding.dart';
import 'contour_repaint_test_painter.dart';
import 'contour_test_harness.dart';

void main() {
  final binding = ContourInitialFrameTestBinding();
  final budget = ContourWorkBudget.shared;

  void begin(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size.square(100);
    addTearDown(() async {
      binding.resetRecording();
      await tester.pumpWidget(const SizedBox.shrink());
      for (var attempt = 0; attempt < 200; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump();
        if (budget.activeBytes == 0 && !ContourProcessorTestHarness.stopping) break;
      }
      tester.view
        ..resetDevicePixelRatio()
        ..resetPhysicalSize();
    });
  }

  Widget scene(Widget child, {double ratio = 1}) => MediaQuery(
    data: MediaQueryData(devicePixelRatio: ratio),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );

  Widget artwork(ValueNotifier<bool> changed) => Padding(
    padding: const EdgeInsets.all(4),
    child: SizedBox.square(dimension: 40, child: CustomPaint(painter: ContourRepaintTestPainter(changed))),
  );

  Widget contour({
    required ContourController controller,
    required Widget child,
    GlobalKey? key,
    bool prepareWhenHidden = true,
  }) => Contour(
    key: key,
    controller: controller,
    prepareWhenHidden: prepareWhenHidden,
    color: const Color(0xFFFFFFFF),
    amount: 3,
    child: child,
  );

  Object? property(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((value) => value.name == name)
      .value;

  Future<void> ready(WidgetTester tester, ContourController controller) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 1));
      if (controller.isReady) return;
    }
    throw StateError('The hidden Contour did not become ready.');
  }

  testWidgets('when offstage content is prepared while hidden, it should become ready before any presentation', (
    tester,
  ) async {
    begin(tester);
    final controller = ContourController();
    final changed = ValueNotifier(false);
    final key = GlobalKey();
    addTearDown(controller.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: artwork(changed)),
        ),
      ),
    );
    await ready(tester, controller);

    expect((controller.isReady, property(key, 'firstPresentationFrameNumber')), (true, -1));
  });

  testWidgets('when held motion hides a child prepared while hidden, it should reveal the prepared pair when played', (
    tester,
  ) async {
    begin(tester);
    final controller = ContourController();
    final changed = ValueNotifier(false);
    final motion = MotionController();
    addTearDown(controller.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Motion(
          controller: motion,
          startup: MotionStartup.hold,
          effect: const FadeInMotionEffect(duration: Duration(milliseconds: 100)),
          child: contour(controller: controller, child: artwork(changed)),
        ),
      ),
    );
    await ready(tester, controller);
    binding.startRecording();
    motion.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    binding.stopRecording();
    final frames = await binding.frames(tester);
    final visible = frames.firstWhere((frame) => ContourTestHarness.pixel(frame, 50, 50)[3] > 0);

    expect(
      [ContourTestHarness.pixel(visible, 50, 50), ContourTestHarness.pixel(visible, 28, 50)],
      [
        [0, 0, 255, 255],
        [255, 255, 255, 255],
      ],
    );
  });

  testWidgets('when a hidden child has never painted without prepareWhenHidden, it should remain unready', (
    tester,
  ) async {
    begin(tester);
    final controller = ContourController();
    final changed = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(controller: controller, prepareWhenHidden: false, child: artwork(changed)),
        ),
      ),
    );
    await tester.pump();

    expect(controller.isReady, false);
  });

  testWidgets('when a widget prepared while hidden changes, it should first reveal only its current shape', (
    tester,
  ) async {
    begin(tester);
    final controller = ContourController();
    final first = ValueNotifier(false);
    final next = ValueNotifier(true);
    final key = GlobalKey();
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(next.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: artwork(first)),
        ),
      ),
    );
    await ready(tester, controller);
    final replacement = artwork(next);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: replacement),
        ),
      ),
    );
    final reset = !controller.isReady;
    await ready(tester, controller);
    binding.startRecording();
    await tester.pumpWidget(
      scene(
        Offstage(
          offstage: false,
          child: contour(key: key, controller: controller, child: replacement),
        ),
      ),
    );
    binding.stopRecording();
    final frames = await binding.frames(tester);

    expect(
      [reset, ContourTestHarness.pixel(frames.first, 35, 50), ContourTestHarness.pixel(frames.first, 55, 50)],
      [
        true,
        [0, 255, 0, 255],
        [0, 0, 0, 0],
      ],
    );
  });

  testWidgets(
    'when a hidden nested repaint boundary changes imperatively, it should prepare current pixels on request',
    (
      tester,
    ) async {
      begin(tester);
      final controller = ContourController();
      final changed = ValueNotifier(false);
      final key = GlobalKey();
      final source = RepaintBoundary(child: artwork(changed));
      addTearDown(controller.dispose);
      addTearDown(changed.dispose);
      await tester.pumpWidget(
        scene(
          Offstage(
            child: contour(key: key, controller: controller, child: source),
          ),
        ),
      );
      await ready(tester, controller);
      changed.value = true;
      controller.prepare();
      final reset = !controller.isReady;
      await ready(tester, controller);
      binding.startRecording();
      await tester.pumpWidget(
        scene(
          Offstage(
            offstage: false,
            child: contour(key: key, controller: controller, child: source),
          ),
        ),
      );
      binding.stopRecording();
      final frames = await binding.frames(tester);

      expect(
        [
          reset,
          ContourTestHarness.pixel(frames.first, 35, 50),
          ContourTestHarness.pixel(frames.first, 28, 50),
          ContourTestHarness.pixel(frames.first, 55, 50),
        ],
        [
          true,
          [0, 255, 0, 255],
          [255, 255, 255, 255],
          [0, 0, 0, 0],
        ],
      );
    },
  );

  testWidgets('when one-off fallback preparation is requested, it should prepare hidden content once', (
    tester,
  ) async {
    // Exercise the sampled fallback and its trace counter.
    ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
    addTearDown(() => ContourCompositeSource.testOverride = null);
    begin(tester);
    final controller = ContourController();
    final changed = ValueNotifier(false);
    final key = GlobalKey();
    addTearDown(controller.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, prepareWhenHidden: false, child: artwork(changed)),
        ),
      ),
    );
    controller.prepare();
    await ready(tester, controller);

    expect((controller.isReady, property(key, 'traceCaptureCount')), (true, 1));
  });

  testWidgets('when hidden density changes after a paint-only update, it should capture current artwork', (
    tester,
  ) async {
    begin(tester);
    final controller = ContourController();
    final changed = ValueNotifier(false);
    final key = GlobalKey();
    final source = RepaintBoundary(child: artwork(changed));
    addTearDown(controller.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: source),
        ),
      ),
    );
    await ready(tester, controller);
    changed.value = true;
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: source),
        ),
        ratio: 2,
      ),
    );
    await ready(tester, controller);
    binding.startRecording();
    await tester.pumpWidget(
      scene(
        Offstage(
          offstage: false,
          child: contour(key: key, controller: controller, child: source),
        ),
        ratio: 2,
      ),
    );
    binding.stopRecording();
    final frames = await binding.frames(tester);

    expect(
      [ContourTestHarness.pixel(frames.first, 35, 50), ContourTestHarness.pixel(frames.first, 55, 50)],
      [
        [0, 255, 0, 255],
        [0, 0, 0, 0],
      ],
    );
  });

  testWidgets(
    'when one-off preparation waits for an inner contour, it should resume without automatic hidden preparation',
    (
      tester,
    ) async {
      begin(tester);
      final outer = ContourController();
      final inner = ContourController();
      final changed = ValueNotifier(false);
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      addTearDown(changed.dispose);
      await tester.pumpWidget(
        scene(
          Offstage(
            child: contour(
              controller: outer,
              prepareWhenHidden: false,
              child: contour(controller: inner, prepareWhenHidden: false, child: artwork(changed)),
            ),
          ),
        ),
      );
      outer.prepare();
      await ready(tester, inner);
      await ready(tester, outer);

      expect((outer.isReady, inner.isReady), (true, true));
    },
  );

  testWidgets('when an inner fallback contour becomes ready, it should wake its waiting hidden outer contour', (
    tester,
  ) async {
    // Exercise the sampled fallback and its trace counter.
    ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
    addTearDown(() => ContourCompositeSource.testOverride = null);
    begin(tester);
    final outer = ContourController();
    final inner = ContourController();
    final changed = ValueNotifier(false);
    final outerKey = GlobalKey();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(
            key: outerKey,
            controller: outer,
            child: contour(controller: inner, child: artwork(changed)),
          ),
        ),
      ),
    );
    await ready(tester, outer);

    expect((outer.isReady, inner.isReady, property(outerKey, 'traceCaptureCount')), (true, true, 1));
  });

  testWidgets('when hidden fallback artwork changes while admission waits, it should prepare only the newest source', (
    tester,
  ) async {
    // Exercise the sampled fallback and its trace counter.
    ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
    addTearDown(() => ContourCompositeSource.testOverride = null);
    begin(tester);
    final blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    addTearDown(blocker!.release);
    final controller = ContourController();
    final first = ValueNotifier(false);
    final next = ValueNotifier(true);
    final key = GlobalKey();
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(next.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: artwork(first)),
        ),
      ),
    );
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: artwork(next)),
        ),
      ),
    );
    final beforeAdmission = (controller.isReady, property(key, 'traceCaptureCount'));
    blocker.release();
    await ready(tester, controller);

    expect((beforeAdmission, property(key, 'traceCaptureCount')), ((false, 0), 1));
  });

  testWidgets('when a waiting hidden contour detaches, it should release its request without signaling readiness', (
    tester,
  ) async {
    begin(tester);
    final blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    addTearDown(blocker!.release);
    final controller = ContourController();
    final changed = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(controller: controller, child: artwork(changed)),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    blocker.release();
    await tester.pump();

    expect(
      (controller.isReady, budget.pendingCount, ContourProcessorTestHarness.admission.deferredCount),
      (false, 0, 0),
    );
  });

  testWidgets('when a waiting fallback owner is replaced, it should prepare only the current owner', (
    tester,
  ) async {
    // Exercise the sampled fallback and its trace counter.
    ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
    addTearDown(() => ContourCompositeSource.testOverride = null);
    begin(tester);
    final blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    addTearDown(blocker!.release);
    final controller = ContourController();
    final previous = ValueNotifier(false);
    final replacement = ValueNotifier(true);
    final key = GlobalKey();
    addTearDown(controller.dispose);
    addTearDown(previous.dispose);
    addTearDown(replacement.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(controller: controller, child: artwork(previous)),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    final source = artwork(replacement);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: source),
        ),
      ),
    );
    final remainedUnready = !controller.isReady;
    blocker.release();
    await ready(tester, controller);
    binding.startRecording();
    await tester.pumpWidget(
      scene(
        Offstage(
          offstage: false,
          child: contour(key: key, controller: controller, child: source),
        ),
      ),
    );
    binding.stopRecording();
    final frames = await binding.frames(tester);

    expect(
      [
        remainedUnready,
        controller.isReady,
        property(key, 'traceCaptureCount'),
        ContourTestHarness.pixel(frames.first, 35, 50),
      ],
      [
        true,
        true,
        1,
        [0, 255, 0, 255],
      ],
    );
  });

  testWidgets('when a hidden prepared source stays unchanged, it should not recapture on later frames', (tester) async {
    begin(tester);
    final controller = ContourController();
    final changed = ValueNotifier(false);
    final key = GlobalKey();
    final source = artwork(changed);
    addTearDown(controller.dispose);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Offstage(
          child: contour(key: key, controller: controller, child: source),
        ),
      ),
    );
    await ready(tester, controller);
    final captures = property(key, 'traceCaptureCount');
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      (controller.isReady, property(key, 'traceCaptureCount'), tester.binding.hasScheduledFrame),
      (true, captures, false),
    );
  });
}
