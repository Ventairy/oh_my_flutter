import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_initial_frame_test_binding.dart';
import 'contour_non_rasterizable_test_source.dart';
import 'contour_solid_test_painter.dart';
import 'contour_test_harness.dart';
import 'contour_thin_bounds_test_source.dart';

void main() {
  final binding = ContourInitialFrameTestBinding();

  tearDown(() {
    binding.resetRecording();
    binding.platformDispatcher.views.single
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  void begin(WidgetTester tester) {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size.square(100);
    binding.startRecording();
  }

  Widget scene(Widget child) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 1),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
  Widget source({Color color = const Color(0xFFFF0000), double size = 20}) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: ContourSolidTestPainter(color: color)),
  );
  Object? property(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((value) => value.name == name)
      .value;
  Future<void> waitForBacking(GlobalKey key) async {
    for (var attempt = 0; attempt < 2000; attempt++) {
      if (property(key, 'contourReady') == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    throw StateError(
      'The initial backing did not finish before presentation: ${key.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties()}',
    );
  }

  testWidgets('when an initial backing is pending, it should omit child pixels from the first application scene', (
    tester,
  ) async {
    begin(tester);
    await tester.pumpWidget(scene(Contour(color: const Color(0xFFFFFFFF), amount: 4, child: source())));
    binding.stopRecording();
    final frames = await binding.frames(tester);

    await ContourTestHarness.settle(tester);
    expect(ContourTestHarness.pixel(frames.first, 50, 50), [0, 0, 0, 0]);
  });

  testWidgets('when an initial backing becomes ready, it should reveal the child and contour in the same scene', (
    tester,
  ) async {
    begin(tester);
    await tester.pumpWidget(scene(Contour(color: const Color(0xFFFFFFFF), amount: 4, child: source())));
    await ContourTestHarness.settle(tester);
    binding.stopRecording();
    final frames = await binding.frames(tester);
    final firstVisible = frames.firstWhere((frame) => ContourTestHarness.pixel(frame, 50, 50)[3] > 0);

    expect(
      [ContourTestHarness.pixel(firstVisible, 50, 50), ContourTestHarness.pixel(firstVisible, 37, 50)],
      [
        [255, 0, 0, 255],
        [255, 255, 255, 255],
      ],
    );
  });

  testWidgets('when the first ready source changes before composition, it should keep the stale pair hidden', (
    tester,
  ) async {
    begin(tester);
    final key = GlobalKey();
    final changed = ValueNotifier(false);
    addTearDown(changed.dispose);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        scene(
          Contour(
            key: key,
            color: const Color(0xFFFFFFFF),
            amount: 4,
            child: RepaintBoundary(
              child: ValueListenableBuilder(
                valueListenable: changed,
                builder: (context, value, child) => source(
                  color: value ? const Color(0xFF00FF00) : const Color(0xFFFF0000),
                  size: value ? 10 : 20,
                ),
              ),
            ),
          ),
        ),
      );
      await waitForBacking(key);
    });
    changed.value = true;
    await tester.pump();
    binding.stopRecording();
    final frames = await binding.frames(tester);

    await ContourTestHarness.settle(tester);
    expect(ContourTestHarness.pixel(frames.last, 50, 50), [0, 0, 0, 0]);
  });

  testWidgets('when all decoration is transparent, it should display the child in the first application scene', (
    tester,
  ) async {
    begin(tester);
    await tester.pumpWidget(scene(Contour(color: const Color(0x00000000), amount: 4, child: source())));
    binding.stopRecording();
    final frames = await binding.frames(tester);

    expect(ContourTestHarness.pixel(frames.first, 50, 50), [255, 0, 0, 255]);
  });

  testWidgets('when a child cannot be captured, it should reveal the live child after the terminal fallback', (
    tester,
  ) async {
    begin(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      scene(
        Contour(
          key: key,
          color: const Color(0xFFFFFFFF),
          amount: 4,
          child: const ContourNonRasterizableTestSource(),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    binding.stopRecording();
    final frames = await binding.frames(tester);

    expect(
      [
        property(key, 'contourReady'),
        ContourTestHarness.pixel(frames.last, 50, 50),
        ContourTestHarness.pixel(frames.last, 37, 50),
      ],
      [
        false,
        [255, 0, 0, 255],
        [0, 0, 0, 0],
      ],
    );
  });

  testWidgets('when an empty capture completes, it should release the initial semantics gate', (tester) async {
    begin(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      scene(
        Contour(
          color: const Color(0xFFFFFFFF),
          amount: 4,
          child: Semantics(label: 'Empty contour source', child: const SizedBox.square(dimension: 20)),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);

    final available = tester.semantics.simulatedAccessibilityTraversal().any(
      (node) => node.label == 'Empty contour source',
    );
    semantics.dispose();
    expect(available, true);
  });

  testWidgets('when the initial child is hidden, it should defer hit testing and semantics until paired presentation', (
    tester,
  ) async {
    begin(tester);
    final semantics = tester.ensureSemantics();
    final key = GlobalKey();
    var taps = 0;
    var semanticsBefore = false;
    var semanticsReady = false;
    var tapsBefore = 0;
    var tapsReady = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        scene(
          Contour(
            key: key,
            color: const Color(0xFFFFFFFF),
            amount: 4,
            child: Semantics(
              label: 'Interactive contour source',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: source(),
              ),
            ),
          ),
        ),
      );
      semanticsBefore = tester.semantics.simulatedAccessibilityTraversal().any(
        (node) => node.label == 'Interactive contour source',
      );
      await tester.tapAt(const Offset(50, 50));
      tapsBefore = taps;
      await waitForBacking(key);
      semanticsReady = tester.semantics.simulatedAccessibilityTraversal().any(
        (node) => node.label == 'Interactive contour source',
      );
      await tester.tapAt(const Offset(50, 50));
      tapsReady = taps;
    });
    await ContourTestHarness.settle(tester);
    final semanticsAfter = tester.semantics.simulatedAccessibilityTraversal().any(
      (node) => node.label == 'Interactive contour source',
    );
    await tester.tapAt(const Offset(50, 50));

    semantics.dispose();
    expect(
      (semanticsBefore, tapsBefore, semanticsReady, tapsReady, semanticsAfter, taps),
      (false, 0, false, 0, true, 1),
    );
  });

  testWidgets('when an already presented source changes, it should keep its updated child live', (tester) async {
    begin(tester);
    final changed = ValueNotifier(false);
    addTearDown(changed.dispose);
    await tester.pumpWidget(
      scene(
        Contour(
          color: const Color(0xFFFFFFFF),
          amount: 4,
          child: RepaintBoundary(
            child: ValueListenableBuilder(
              valueListenable: changed,
              builder: (context, value, child) => source(
                color: value ? const Color(0xFF00FF00) : const Color(0xFFFF0000),
                size: value ? 10 : 20,
              ),
            ),
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    changed.value = true;
    await tester.pump();
    binding.stopRecording();
    final frames = await binding.frames(tester);
    await ContourTestHarness.settle(tester);

    expect(
      [ContourTestHarness.pixel(frames.last, 50, 50), ContourTestHarness.pixel(frames.last, 37, 50)],
      [
        [0, 255, 0, 255],
        [0, 0, 0, 0],
      ],
    );
  });

  testWidgets('when contours are nested initially, it should reveal both backings with the child and its interaction', (
    tester,
  ) async {
    begin(tester);
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      scene(
        Contour(
          color: const Color(0xFF000000),
          amount: 3,
          child: Contour(
            color: const Color(0xFFFFFFFF),
            amount: 3,
            child: Semantics(
              label: 'Nested contour source',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: source(),
              ),
            ),
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    binding.stopRecording();
    final frames = await binding.frames(tester);
    final firstVisible = frames.firstWhere((frame) => ContourTestHarness.pixel(frame, 50, 50)[3] > 0);
    final available = tester.semantics.simulatedAccessibilityTraversal().any(
      (node) => node.label == 'Nested contour source',
    );
    await tester.tapAt(const Offset(50, 50));
    semantics.dispose();

    expect(
      [
        ContourTestHarness.pixel(firstVisible, 50, 50),
        ContourTestHarness.pixel(firstVisible, 38, 50),
        ContourTestHarness.pixel(firstVisible, 35, 50),
        available,
        taps,
      ],
      [
        [255, 0, 0, 255],
        [255, 255, 255, 255],
        [0, 0, 0, 255],
        true,
        1,
      ],
    );
  });

  testWidgets('when startup artwork changes several times then settles, it should first reveal the latest pair', (
    tester,
  ) async {
    begin(tester);
    final budget = ContourWorkBudget.shared;
    final lease = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    final changed = ValueNotifier(0);
    addTearDown(changed.dispose);
    try {
      await tester.pumpWidget(
        scene(
          Contour(
            color: const Color(0xFFFFFFFF),
            amount: 4,
            child: RepaintBoundary(
              child: ValueListenableBuilder(
                valueListenable: changed,
                builder: (context, value, child) => source(
                  color: switch (value) {
                    0 => const Color(0xFFFF0000),
                    1 => const Color(0xFF0000FF),
                    _ => const Color(0xFF00FF00),
                  },
                  size: value == 2 ? 10 : 20,
                ),
              ),
            ),
          ),
        ),
      );
      changed.value = 1;
      await tester.pump();
      changed.value = 2;
      await tester.pump();
    } finally {
      lease!.release();
    }
    await ContourTestHarness.settle(tester);
    binding.stopRecording();
    final frames = await binding.frames(tester);
    final firstVisible = frames.firstWhere((frame) => ContourTestHarness.pixel(frame, 50, 50)[3] > 0);

    expect(
      [
        ContourTestHarness.pixel(firstVisible, 50, 50),
        ContourTestHarness.pixel(firstVisible, 42, 50),
        ContourTestHarness.pixel(firstVisible, 37, 50),
      ],
      [
        [0, 255, 0, 255],
        [255, 255, 255, 255],
        [0, 0, 0, 0],
      ],
    );
  });

  testWidgets('when an unpainted nested contour is pending, it should still reveal the painted source and backing', (
    tester,
  ) async {
    begin(tester);
    await tester.pumpWidget(
      scene(
        Contour(
          color: const Color(0xFFFFFFFF),
          amount: 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              source(),
              Opacity(
                opacity: 0,
                child: Contour(color: const Color(0xFF000000), amount: 3, child: source()),
              ),
            ],
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    binding.stopRecording();
    final frames = await binding.frames(tester);
    final firstVisible = frames.firstWhere((frame) => ContourTestHarness.pixel(frame, 50, 50)[3] > 0);

    expect(
      [ContourTestHarness.pixel(firstVisible, 50, 50), ContourTestHarness.pixel(firstVisible, 37, 50)],
      [
        [255, 0, 0, 255],
        [255, 255, 255, 255],
      ],
    );
  });

  testWidgets(
    'when the amount changes while initial capture waits, it should show the latest contour with one capture',
    (
      tester,
    ) async {
      begin(tester);
      final key = GlobalKey();
      final amount = ValueNotifier<double>(2);
      addTearDown(amount.dispose);
      final budget = ContourWorkBudget.shared;
      final lease = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
      try {
        await tester.pumpWidget(
          scene(
            ValueListenableBuilder(
              valueListenable: amount,
              builder: (context, value, child) => Contour(
                key: key,
                color: const Color(0xFFFFFFFF),
                amount: value,
                child: child!,
              ),
              child: source(),
            ),
          ),
        );
        amount.value = 6;
        await tester.pump();
      } finally {
        lease!.release();
      }
      await ContourTestHarness.settle(tester);
      binding.stopRecording();
      final frames = await binding.frames(tester);
      final firstVisible = frames.firstWhere((frame) => ContourTestHarness.pixel(frame, 50, 50)[3] > 0);

      expect(
        [property(key, 'captureCount'), ContourTestHarness.pixel(firstVisible, 35, 50)],
        [
          1,
          [255, 255, 255, 255],
        ],
      );
    },
  );

  testWidgets('when initial capture exceeds admission, it should reveal the child without allocating a snapshot', (
    tester,
  ) async {
    begin(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      scene(
        Contour(
          key: key,
          color: const Color(0xFFFFFFFF),
          amount: 4,
          child: const ContourThinBoundsTestSource(),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    binding.stopRecording();
    final frames = await binding.frames(tester);

    expect(
      [property(key, 'contourReady'), property(key, 'captureCount'), ContourTestHarness.pixel(frames.last, 50, 50)],
      [
        false,
        0,
        [255, 0, 0, 255],
      ],
    );
  });

  testWidgets('when fallback glyph geometry is warm, it should reveal its first paired scene without capturing', (
    tester,
  ) async {
    // Keep native glyph proof/cache coverage independent of atlas routing.
    ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
    addTearDown(() => ContourCompositeSource.testOverride = null);
    begin(tester);
    final keeper = GlobalKey();
    final cold = GlobalKey();
    final warm = GlobalKey();
    Widget composition(GlobalKey key) => scene(
      Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Contour(
                key: key,
                color: const Color(0xFFFFFFFF),
                amount: 4,
                child: const Text(
                  'OO',
                  style: TextStyle(fontFamily: 'Ahem', fontSize: 18, color: Color(0xFFFF0000)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Contour(key: keeper, color: const Color(0x00000000), child: const SizedBox.shrink()),
          ),
        ],
      ),
    );
    await tester.pumpWidget(composition(cold));
    await ContourTestHarness.settle(tester);
    final coldAccepted = property(cold, 'nativeTextActive');
    final reference = (await binding.frames(tester)).last;
    binding.startRecording();
    await tester.pumpWidget(composition(warm));
    binding.stopRecording();
    final frames = await binding.frames(tester);
    await ContourTestHarness.settle(tester);

    var differingChannels = 0;
    var redPixels = 0;
    var whitePixels = 0;
    for (var index = 0; index < reference.length; index += 4) {
      if (reference[index] == 255 &&
          reference[index + 1] == 0 &&
          reference[index + 2] == 0 &&
          reference[index + 3] == 255) {
        redPixels++;
      }
      if (reference[index] == 255 &&
          reference[index + 1] == 255 &&
          reference[index + 2] == 255 &&
          reference[index + 3] == 255) {
        whitePixels++;
      }
      for (var channel = 0; channel < 4; channel++) {
        if (reference[index + channel] != frames.first[index + channel]) differingChannels++;
      }
    }

    expect(
      [
        coldAccepted,
        property(warm, 'nativeTextActive'),
        property(warm, 'captureCount'),
        redPixels > 0,
        whitePixels > 0,
        differingChannels,
      ],
      [true, true, 0, true, true, 0],
    );
  });
}
