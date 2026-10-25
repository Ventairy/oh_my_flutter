import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart' show ContourProcessorTestHarness;
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_solid_test_painter.dart';
import 'contour_test_harness.dart';
import 'contour_work_selection_registrar.dart';

void main() {
  final budget = ContourWorkBudget.shared;

  Future<void> finishShutdown(WidgetTester tester) async {
    // Keep this fake async scope alive until real capture/worker cleanup ends.
    // A later widget test cannot pump continuations owned by this scope.
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
      if (budget.activeBytes == 0 && !ContourProcessorTestHarness.stopping) return;
    }
    throw StateError('Contour processing did not finish shutdown.');
  }

  Widget scene(Widget child) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 1),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );

  Widget glyph(GlobalKey key, {double size = 24, Color color = const Color(0xFFFFFFFF)}) => Contour(
    key: key,
    color: color,
    amount: 3,
    child: Text(
      'O',
      style: TextStyle(fontFamily: 'Ahem', fontSize: size, color: const Color(0xFFFF0000)),
    ),
  );

  Object? diagnostic(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((property) => property.name == name)
      .value;

  testWidgets('when forty tiny sources mount together, it should admit their captures without frame pacing', (
    tester,
  ) async {
    final keys = List<GlobalKey>.generate(40, (_) => GlobalKey());
    await tester.pumpWidget(
      scene(
        Wrap(
          children: [
            for (final key in keys)
              Contour(
                key: key,
                color: const Color(0xFFFFFFFF),
                child: const SizedBox.square(dimension: 6, child: CustomPaint(painter: ContourSolidTestPainter())),
              ),
          ],
        ),
      ),
    );
    await tester.pump();
    final started = keys.where((key) => (diagnostic(key, 'captureCount')! as int) > 0).length;
    final queued = budget.pendingCount;
    await ContourTestHarness.settle(tester);
    expect((started, queued), (40, 0));
  });

  testWidgets('when native eligibility grows after admission, it should keep proof inside its reservation', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      scene(
        Contour(
          key: key,
          color: const Color(0xFFFFFFFF),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: RichText(
              selectionRegistrar: ContourWorkSelectionRegistrar(),
              selectionColor: const Color(0xFF0000FF),
              text: const TextSpan(
                text: 'O',
                style: TextStyle(fontFamily: 'Ahem', fontSize: 100, color: Color(0xFFFF0000)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final wasAdmitted = (diagnostic(key, 'captureCount')! as int) > 0 && budget.activeBytes > 0;
    // Removing registration does not mark unchanged text for repaint. The
    // already-admitted source has therefore reserved only generic tracing.
    tester.renderObject<RenderParagraph>(find.byType(RichText)).registrar = null;
    await ContourTestHarness.settle(tester);
    expect(
      (wasAdmitted, diagnostic(key, 'contourReady'), diagnostic(key, 'nativeTextVerificationCount')),
      (true, true, 0),
    );
  });

  testWidgets('when a large source exceeds remaining capacity, it should wait before allocating an image', (
    tester,
  ) async {
    final blocker = await budget.request(bytes: budget.maxBytes ~/ 2, owner: Object()).future;
    final key = GlobalKey();
    try {
      await tester.pumpWidget(
        scene(
          SizedBox.square(
            dimension: 10,
            child: OverflowBox(
              minWidth: 1000,
              maxWidth: 1000,
              minHeight: 1000,
              maxHeight: 1000,
              child: Contour(
                key: key,
                color: const Color(0xFFFFFFFF),
                child: const SizedBox.square(dimension: 1000, child: ColoredBox(color: Color(0xFFFF0000))),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect((diagnostic(key, 'captureCount'), budget.pendingCount), (0, 1));
    } finally {
      // Detach before releasing the blocker, so this regression never creates
      // the large image it verifies would otherwise have been allocated.
      await tester.pumpWidget(const SizedBox());
      blocker?.release();
      await finishShutdown(tester);
    }
  });

  testWidgets('when the last active owner detaches, it should drain its reservation and restart cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(scene(glyph(GlobalKey())));
    await tester.pumpWidget(const SizedBox());
    await finishShutdown(tester);
    final drained = await tester.runAsync(() => budget.request(bytes: budget.maxBytes, owner: Object()).future);
    drained!.release();
    final key = GlobalKey();
    await tester.pumpWidget(scene(glyph(key, size: 16)));
    await ContourTestHarness.settle(tester);
    expect((diagnostic(key, 'contourReady'), budget.activeBytes, budget.pendingCount), (true, 0, 0));
  });

  testWidgets('when a queued source changes, it should capture only its newest geometry', (tester) async {
    final blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    final key = GlobalKey();
    try {
      await tester.pumpWidget(scene(glyph(key)));
      await tester.pumpWidget(scene(glyph(key, size: 8)));
      await tester.pump();
      final capturesWhileQueued = diagnostic(key, 'captureCount');
      blocker!.release();
      await ContourTestHarness.settle(tester);
      final bounds = (key.currentContext!.findRenderObject()! as RenderBox).paintBounds;
      expect((capturesWhileQueued, bounds.width < 24, budget.pendingCount), (0, true, 0));
    } finally {
      blocker?.release();
      await tester.pumpWidget(const SizedBox());
      await finishShutdown(tester);
    }
  });

  testWidgets('when a queued contour detaches, it should release its ticket without capturing', (tester) async {
    final blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    try {
      await tester.pumpWidget(scene(glyph(GlobalKey())));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      blocker!.release();
      expect((budget.pendingCount, budget.activeCount, budget.activeBytes), (0, 0, 0));
    } finally {
      blocker?.release();
      await finishShutdown(tester);
    }
  });

  testWidgets('when queued decoration becomes transparent, it should cancel its image request', (tester) async {
    final blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    final key = GlobalKey();
    try {
      await tester.pumpWidget(scene(glyph(key)));
      await tester.pumpWidget(scene(glyph(key, color: const Color(0x00000000))));
      await tester.pump();
      expect((budget.pendingCount, diagnostic(key, 'captureCount')), (0, 0));
    } finally {
      blocker?.release();
      await tester.pumpWidget(const SizedBox());
      await finishShutdown(tester);
    }
  });

  testWidgets('when a shared-cache waiter becomes hidden, it should finish its cancelled generation', (tester) async {
    final blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    final first = GlobalKey();
    final second = GlobalKey();
    try {
      await tester.pumpWidget(scene(Row(mainAxisSize: MainAxisSize.min, children: [glyph(first), glyph(second)])));
      await tester.pump();
      await tester.pumpWidget(
        scene(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph(first),
              glyph(second, color: const Color(0x00000000)),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(diagnostic(second, 'generating'), isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox());
      blocker?.release();
      await finishShutdown(tester);
    }
  });

  testWidgets('when a shared-cache waiter changes, it should stop waiting on the obsolete owner', (tester) async {
    final blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
    final first = GlobalKey();
    final second = GlobalKey();
    try {
      await tester.pumpWidget(scene(Row(mainAxisSize: MainAxisSize.min, children: [glyph(first), glyph(second)])));
      await tester.pump();
      await tester.pumpWidget(
        scene(Row(mainAxisSize: MainAxisSize.min, children: [glyph(first), glyph(second, size: 8)])),
      );
      await tester.pump();
      final queued = budget.pendingCount + ContourProcessorTestHarness.admission.deferredCount;
      blocker!.release();
      await ContourTestHarness.settle(tester);
      expect((queued, diagnostic(second, 'contourReady'), budget.activeBytes), (2, true, 0));
    } finally {
      blocker?.release();
      await tester.pumpWidget(const SizedBox());
      await finishShutdown(tester);
    }
  });
}
