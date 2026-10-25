import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as fallback;
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_native_test_harness.dart';
import 'contour_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  setUp(() {
    // These checks own the portable worker lifecycle, independently of native
    // atlas support available on the host running the test.
    ContourCompositeSource.testOverride = fallback.ContourCompositeSource.shared;
  });
  tearDown(() => ContourCompositeSource.testOverride = null);

  Future<void> finishWorker(WidgetTester tester) async {
    for (
      var attempt = 0;
      attempt < 200 && (ContourProcessorTestHarness.prepared || ContourProcessorTestHarness.stopping);
      attempt++
    ) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('when the last generic owner detaches, it should stop processing while a declared owner remains', (
    tester,
  ) async {
    final declaredKey = GlobalKey();
    final genericKey = GlobalKey();
    Widget scene({required bool generic}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          if (generic)
            Contour(
              key: genericKey,
              color: const Color(0xFFFFFFFF),
              amount: 4,
              child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
            ),
          Contour(
            key: declaredKey,
            color: const Color(0xFFFFFFFF),
            amount: 4,
            child: const SizedBox.square(
              dimension: 40,
              child: DecoratedBox(decoration: BoxDecoration(color: Color(0xff7948ec))),
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(scene(generic: true));
    await ContourTestHarness.settle(tester);
    final preparedBefore = ContourProcessorTestHarness.prepared;
    final exitsBefore = ContourProcessorTestHarness.exits;
    final scratchBefore = ContourProcessorTestHarness.admission.activeScratchBytes;
    await tester.pumpWidget(scene(generic: false));
    await finishWorker(tester);
    final properties = declaredKey.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties();
    Object? value(String name) => properties.firstWhere((p) => p.name == name).value;
    final actual = (
      preparedBefore,
      scratchBefore,
      ContourProcessorTestHarness.prepared,
      ContourProcessorTestHarness.exits > exitsBefore,
      value('declaredPathActive'),
      value('captureCount'),
      ContourProcessorTestHarness.admission.activeScratchBytes,
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    expect(actual, (true, 0, false, true, true, 0, 0));
  }, skip: kIsWeb);
  testWidgets('when the last generic owner detaches, it should stop processing while a known box owner remains', (
    tester,
  ) async {
    final declaredKey = GlobalKey();
    final genericKey = GlobalKey();
    Widget scene({required bool generic}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          if (generic)
            Contour(
              key: genericKey,
              color: const Color(0xFFFFFFFF),
              amount: 4,
              child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
            ),
          Contour(
            key: declaredKey,
            color: const Color(0xFFFFFFFF),
            amount: 4,
            child: const SizedBox.square(
              dimension: 40,
              child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF7948EC))),
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(scene(generic: true));
    await ContourTestHarness.settle(tester);
    final preparedBefore = ContourProcessorTestHarness.prepared;
    final exitsBefore = ContourProcessorTestHarness.exits;
    final scratchBefore = ContourProcessorTestHarness.admission.activeScratchBytes;
    await tester.pumpWidget(scene(generic: false));
    await finishWorker(tester);
    final properties = declaredKey.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties();
    Object? value(String name) => properties.firstWhere((p) => p.name == name).value;
    final actual = (
      preparedBefore,
      scratchBefore,
      ContourProcessorTestHarness.prepared,
      ContourProcessorTestHarness.exits > exitsBefore,
      value('declaredPathActive'),
      value('captureCount'),
      ContourProcessorTestHarness.admission.activeScratchBytes,
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    expect(actual, (true, 0, false, true, true, 0, 0));
  }, skip: kIsWeb);
  testWidgets(
    'when an unknown widget builds a known box, it should release speculative processing after discovery',
    (tester) async {
      final key = GlobalKey();
      bool? preparedDuringBuild;
      final exitsBefore = ContourProcessorTestHarness.exits;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Contour(
              key: key,
              color: const Color(0xFFFFFFFF),
              amount: 4,
              child: Builder(
                builder: (_) {
                  preparedDuringBuild = ContourProcessorTestHarness.prepared;
                  return const SizedBox.square(
                    dimension: 40,
                    child: DecoratedBox(decoration: BoxDecoration(color: Color(0xff7948ec))),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await finishWorker(tester);
      final properties = key.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties();
      Object? value(String name) => properties.firstWhere((p) => p.name == name).value;
      final actual = (
        preparedDuringBuild,
        ContourProcessorTestHarness.prepared,
        ContourProcessorTestHarness.exits > exitsBefore,
        value('captureCount'),
        value('firstPresentationHasContour'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await finishWorker(tester);
      expect(actual, (true, false, true, 0, true));
    },
    skip: kIsWeb,
  );

  testWidgets(
    'when a known box becomes custom artwork and later becomes a box again, it should acquire processing only while needed',
    (tester) async {
      final key = GlobalKey();
      Widget scene({required bool declared}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Contour(
            key: key,
            color: const Color(0xFFFFFFFF),
            amount: 4,
            child: declared
                ? const SizedBox.square(
                    dimension: 40,
                    child: DecoratedBox(decoration: BoxDecoration(color: Color(0xff7948ec))),
                  )
                : const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
          ),
        ),
      );
      await tester.pumpWidget(scene(declared: true));
      final before = ContourProcessorTestHarness.prepared;
      await tester.pumpWidget(scene(declared: false));
      await ContourTestHarness.settle(tester);
      final fallback = ContourProcessorTestHarness.prepared;
      final captures =
          key.currentContext!
                  .findRenderObject()!
                  .toDiagnosticsNode()
                  .getProperties()
                  .firstWhere((p) => p.name == 'captureCount')
                  .value!
              as int;
      await tester.pumpWidget(scene(declared: true));
      for (var attempt = 0; attempt < 200; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump(const Duration(milliseconds: 1));
        if (key.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties().any(
          (p) => p.name == 'declaredPathActive' && p.value == true,
        )) {
          break;
        }
      }
      await finishWorker(tester);
      final properties = key.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties();
      Object? value(String name) => properties.firstWhere((p) => p.name == name).value;
      final actual = (
        before,
        fallback,
        captures > 0,
        ContourProcessorTestHarness.prepared,
        value('declaredPathActive'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await finishWorker(tester);
      expect(actual, (false, true, true, false, true));
    },
    skip: kIsWeb,
  );

  testWidgets('when a declared path replaces a blocked trace, it should release capacity only after worker exit', (
    tester,
  ) async {
    final spawned = Completer<void>();
    final resume = Completer<void>();
    final key = GlobalKey();
    ContourProcessorTestHarness.afterSpawn = (_) async {
      spawned.complete();
      await resume.future;
    };
    Widget scene({required bool declared}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Contour(
          key: key,
          color: const Color(0xFFFFFFFF),
          amount: 4,
          child: declared
              ? const SizedBox.square(
                  dimension: 40,
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xff7948ec))),
                )
              : const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
        ),
      ),
    );
    Object? value(String name) => key.currentContext!
        .findRenderObject()!
        .toDiagnosticsNode()
        .getProperties()
        .firstWhere((p) => p.name == name)
        .value;
    try {
      await tester.pumpWidget(scene(declared: false));
      for (var attempt = 0; attempt < 200 && !spawned.isCompleted; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump(const Duration(milliseconds: 1));
      }
      for (var attempt = 0; attempt < 200; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump(const Duration(milliseconds: 1));
        if ((value('captureCount')! as int) > 0 && ContourProcessorTestHarness.activeNative != null) break;
      }
      final captures = value('captureCount');
      final before = ContourProcessorTestHarness.admission.activeScratchBytes > 0;
      await tester.pumpWidget(scene(declared: true));
      final held = ContourProcessorTestHarness.admission.activeScratchBytes > 0;
      resume.complete();
      await finishWorker(tester);
      final actual = (
        before,
        held,
        ContourProcessorTestHarness.prepared,
        ContourProcessorTestHarness.admission.activeScratchBytes,
        ContourProcessorTestHarness.acknowledgements,
        ContourProcessorTestHarness.queuedNative,
        value('declaredPathActive'),
        value('captureCount') == captures,
        value('lastMainCompositionHasContour'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(actual, (true, true, false, 0, 0, 0, true, true, true));
    } finally {
      ContourProcessorTestHarness.afterSpawn = null;
      if (!resume.isCompleted) resume.complete();
    }
  }, skip: kIsWeb);
  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await finishWorker(tester);
    if (ContourProcessorTestHarness.prepared || ContourProcessorTestHarness.stopping) {
      throw StateError('Contour processing did not finish cleanup.');
    }
  }

  testWidgets(
    'when an undecorated contour stays mounted, it should let the last processing client retire its worker',
    (tester) async {
      final harness = ContourNativeTestHarness();
      final starts = ContourProcessorTestHarness.starts;
      final exits = ContourProcessorTestHarness.exits;
      var syntheticAttached = false;
      late final Object observed;
      try {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Center(
                child: Contour(
                  key: harness.backdropKey,
                  color: const Color(0x00000000),
                  child: ContourNativeTestHarness.glyph,
                ),
              ),
            ),
          ),
        );
        ContourProcessorTestHarness.acquire();
        syntheticAttached = true;
        ContourProcessorTestHarness.prepare();
        for (var attempt = 0; attempt < 200 && !ContourProcessorTestHarness.ready; attempt++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          await tester.pump(const Duration(milliseconds: 1));
        }
        final started = (ContourProcessorTestHarness.ready, ContourProcessorTestHarness.starts - starts);
        ContourProcessorTestHarness.release();
        syntheticAttached = false;
        await finishWorker(tester);
        observed = (
          started,
          harness.backdropKey.currentContext != null,
          harness.captureCount,
          ContourProcessorTestHarness.prepared,
          ContourProcessorTestHarness.stopping,
          ContourProcessorTestHarness.exits - exits,
          ContourProcessorTestHarness.acknowledgements,
          ContourProcessorTestHarness.queuedNative,
          ContourProcessorTestHarness.activeNative,
          ContourWorkBudget.shared.activeBytes,
          ContourWorkBudget.shared.pendingCount,
        );
      } finally {
        if (syntheticAttached) ContourProcessorTestHarness.release();
        await cleanup(tester);
      }
      expect(observed, ((true, 1), true, 0, false, false, 1, 0, 0, null, 0, 0));
    },
    skip: kIsWeb,
  );

  testWidgets(
    'when a blocked generic contour loses its decoration, it should drain processing while remaining mounted',
    (tester) async {
      final budget = ContourWorkBudget.shared;
      final blocker = (await budget.request(bytes: budget.maxBytes, owner: Object()).future)!;
      final harness = ContourNativeTestHarness();
      final controller = ContourController();
      final starts = ContourProcessorTestHarness.starts;
      final exits = ContourProcessorTestHarness.exits;
      Widget scene({required bool decorated}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Center(
            child: Contour(
              key: harness.backdropKey,
              controller: controller,
              color: decorated ? const Color(0xFFFFFFFF) : const Color(0x00000000),
              amount: 4,
              child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
            ),
          ),
        ),
      );
      late final Object observed;
      try {
        await tester.pumpWidget(scene(decorated: true));
        for (
          var attempt = 0;
          attempt < 200 && (budget.pendingCount == 0 || !ContourProcessorTestHarness.ready);
          attempt++
        ) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          await tester.pump(const Duration(milliseconds: 1));
        }
        final blocked = (
          budget.pendingCount > 0,
          harness.captureCount,
          ContourProcessorTestHarness.ready,
          ContourProcessorTestHarness.starts - starts,
        );
        await tester.pumpWidget(scene(decorated: false));
        blocker.release();
        await ContourTestHarness.settle(tester);
        await finishWorker(tester);
        observed = (
          blocked,
          harness.backdropKey.currentContext != null,
          controller.isReady,
          harness.captureCount,
          budget.activeBytes,
          budget.pendingCount,
          ContourProcessorTestHarness.acknowledgements,
          ContourProcessorTestHarness.queuedNative,
          ContourProcessorTestHarness.activeNative,
          ContourProcessorTestHarness.nativePortJobCount,
          ContourProcessorTestHarness.prepared,
          ContourProcessorTestHarness.stopping,
          ContourProcessorTestHarness.exits - exits,
        );
      } finally {
        blocker.release();
        await cleanup(tester);
        controller.dispose();
      }
      expect(observed, ((true, 0, true, 1), true, true, 0, 0, 0, 0, 0, null, 0, false, false, 1));
    },
    skip: kIsWeb,
  );

  testWidgets(
    'when an undecorated contour gains new artwork and decoration, it should restart processing for the new shape',
    (tester) async {
      final harness = ContourNativeTestHarness();
      final controller = ContourController();
      final starts = ContourProcessorTestHarness.starts;
      final exits = ContourProcessorTestHarness.exits;
      Widget scene({required bool decorated, required bool circle}) => MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: harness.boundaryKey,
              child: SizedBox.square(
                dimension: 100,
                child: Center(
                  child: Center(
                    child: Contour(
                      key: harness.backdropKey,
                      controller: controller,
                      color: decorated ? const Color(0xFFFFFFFF) : const Color(0x00000000),
                      amount: 4,
                      child: CustomPaint(
                        size: const Size.square(40),
                        painter: ContourTestPainter(circle: circle),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      late final Object observed;
      try {
        await tester.pumpWidget(scene(decorated: true, circle: false));
        await ContourTestHarness.settle(tester);
        final firstCaptures = harness.captureCount;
        await tester.pumpWidget(scene(decorated: false, circle: true));
        await ContourTestHarness.settle(tester);
        await finishWorker(tester);
        final retired = (
          controller.isReady,
          harness.captureCount == firstCaptures,
          ContourProcessorTestHarness.prepared,
          ContourProcessorTestHarness.stopping,
          ContourProcessorTestHarness.exits - exits,
        );
        await tester.pumpWidget(scene(decorated: true, circle: true));
        await ContourTestHarness.settle(tester);
        final restarted = (
          controller.isReady,
          harness.captureCount > firstCaptures,
          ContourProcessorTestHarness.prepared,
          ContourProcessorTestHarness.starts - starts,
          ContourProcessorTestHarness.acknowledgements,
          ContourProcessorTestHarness.queuedNative,
          ContourWorkBudget.shared.activeBytes,
          ContourWorkBudget.shared.pendingCount,
        );
        final actual = await harness.pixels(tester, pixelRatio: 4);
        await cleanup(tester);
        final reference = ContourTestHarness();
        await reference.mount(
          tester,
          amount: 4,
          pixelRatio: 3,
          child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(circle: true)),
        );
        final expected = await reference.pixels(tester, pixelRatio: 4);
        observed = (firstCaptures > 0, retired, restarted, listEquals(actual, expected));
      } finally {
        await cleanup(tester);
        controller.dispose();
      }
      expect(observed, (true, (true, true, false, false, 1), (true, true, true, 2, 0, 0, 0, 0), true));
    },
    skip: kIsWeb,
  );
}
