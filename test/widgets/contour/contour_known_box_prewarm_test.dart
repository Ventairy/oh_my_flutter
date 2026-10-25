import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

void main() {
  // Exercise worker preparation when automatic atlas capture is unavailable.
  setUp(() => ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared);
  tearDown(() => ContourCompositeSource.testOverride = null);

  const opaqueBox = SizedBox(
    width: 50,
    height: 40,
    child: DecoratedBox(decoration: BoxDecoration(color: Color(0xffff0000))),
  );

  Widget scene(GlobalKey contour, Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: Contour(
        key: contour,
        color: const Color(0xffffffff),
        amount: 4,
        child: Padding(padding: const EdgeInsets.all(8), child: child),
      ),
    ),
  );

  Object? diagnostic(GlobalKey contour, String name) => contour.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((property) => property.name == name)
      .value;

  Future<void> unmountAndStop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (!ContourProcessorTestHarness.stopping &&
          !ContourProcessorTestHarness.prepared &&
          ContourWorkBudget.shared.activeBytes == 0) {
        return;
      }
    }
    throw StateError(
      'Contour worker shutdown did not release its work capacity.',
    );
  }

  testWidgets(
    'when a supported opaque box first appears, it should present its first main contour without requesting worker preparation',
    (tester) async {
      await unmountAndStop(tester);
      addTearDown(() => unmountAndStop(tester));
      final contour = GlobalKey();
      final before = ContourProcessorTestHarness.prepared;
      final starts = ContourProcessorTestHarness.starts;
      await tester.pumpWidget(scene(contour, opaqueBox));

      expect(
        (
          before,
          ContourProcessorTestHarness.prepared,
          ContourProcessorTestHarness.starts - starts,
          diagnostic(contour, 'captureCount'),
          diagnostic(contour, 'declaredPathActive'),
          diagnostic(contour, 'firstPresentationHasContour'),
        ),
        (false, false, 0, 0, true, true),
      );
    },
    skip: kIsWeb,
  );

  testWidgets(
    'when an ordinary text descendant builds, it should already have requested worker preparation',
    (tester) async {
      await unmountAndStop(tester);
      addTearDown(() => unmountAndStop(tester));
      final before = ContourProcessorTestHarness.prepared;
      bool? preparedDuringBuild;
      await tester.pumpWidget(
        scene(
          GlobalKey(),
          Builder(
            builder: (_) {
              preparedDuringBuild = ContourProcessorTestHarness.prepared;
              return const Text('Ordinary');
            },
          ),
        ),
      );

      expect((before, preparedDuringBuild), (false, true));
    },
    skip: kIsWeb,
  );

  testWidgets(
    'when a supported box becomes ordinary text, it should prepare before the new descendant builds on the same owner',
    (tester) async {
      await unmountAndStop(tester);
      addTearDown(() => unmountAndStop(tester));
      final contour = GlobalKey();
      final before = ContourProcessorTestHarness.prepared;
      await tester.pumpWidget(scene(contour, opaqueBox));
      final knownBoxPrepared = ContourProcessorTestHarness.prepared;
      final renderBefore = contour.currentContext!.findRenderObject();
      bool? preparedDuringBuild;
      await tester.pumpWidget(
        scene(
          contour,
          Builder(
            builder: (_) {
              preparedDuringBuild = ContourProcessorTestHarness.prepared;
              return const Text('Ordinary');
            },
          ),
        ),
      );

      expect(
        (
          before,
          knownBoxPrepared,
          preparedDuringBuild,
          identical(renderBefore, contour.currentContext!.findRenderObject()),
          diagnostic(contour, 'declaredPathActive'),
        ),
        (false, false, true, true, false),
      );
    },
    skip: kIsWeb,
  );

  testWidgets(
    'when an unsupported box has a child, it should already have requested preparation before that descendant builds',
    (tester) async {
      await unmountAndStop(tester);
      addTearDown(() => unmountAndStop(tester));
      final contour = GlobalKey();
      final before = ContourProcessorTestHarness.prepared;
      bool? preparedDuringBuild;
      await tester.pumpWidget(
        scene(
          contour,
          SizedBox(
            width: 50,
            height: 40,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xffff0000)),
              child: Builder(
                builder: (_) {
                  preparedDuringBuild = ContourProcessorTestHarness.prepared;
                  return const ColoredBox(color: Color(0xFF00FF00));
                },
              ),
            ),
          ),
        ),
      );

      expect(
        (
          before,
          preparedDuringBuild,
          diagnostic(contour, 'declaredPathActive'),
        ),
        (false, true, false),
      );
    },
    skip: kIsWeb,
  );
}
