import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import 'contour_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  Future<void> unmountAndStop(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
  }

  testWidgets(
    'when an ordinary text descendant builds, it should already have requested worker preparation',
    (tester) async {
      await unmountAndStop(tester);
      final before = ContourProcessorTestHarness.prepared;
      bool? preparedDuringBuild;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Contour(
              color: const Color(0xFFFFFFFF),
              child: Builder(
                builder: (_) {
                  preparedDuringBuild = ContourProcessorTestHarness.prepared;
                  return const Text('Ordinary');
                },
              ),
            ),
          ),
        ),
      );
      final observed = (before, preparedDuringBuild);
      await unmountAndStop(tester);
      expect(observed, (false, true));
    },
    skip: kIsWeb,
  );

  testWidgets(
    'when a known box first appears, it should present its contour without preparing a worker',
    (tester) async {
      await unmountAndStop(tester);
      final before = ContourProcessorTestHarness.prepared;
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Contour(
              key: key,
              color: const Color(0xFFFFFFFF),
              amount: 4,
              child: const SizedBox.square(
                dimension: 40,
                child: DecoratedBox(decoration: BoxDecoration(color: Color(0xff7948ec))),
              ),
            ),
          ),
        ),
      );
      final properties = key.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties();
      Object? value(String name) => properties.firstWhere((property) => property.name == name).value;
      final observed = (
        before,
        ContourProcessorTestHarness.prepared,
        value('captureCount'),
        value('declaredPathActive'),
        value('firstPresentationHasContour'),
      );
      await unmountAndStop(tester);
      expect(observed, (false, false, 0, true, true));
    },
    skip: kIsWeb,
  );

  testWidgets(
    'when a declared child becomes ordinary on the fallback renderer, it should prepare before the new descendant builds',
    (tester) async {
      // Exercise eager worker preparation when atlas capture is unavailable.
      ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
      addTearDown(() => ContourCompositeSource.testOverride = null);
      await unmountAndStop(tester);
      final before = ContourProcessorTestHarness.prepared;
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Contour(
              key: key,
              color: const Color(0xFFFFFFFF),
              amount: 4,
              child: const SizedBox.square(
                dimension: 40,
                child: DecoratedBox(decoration: BoxDecoration(color: Color(0xff7948ec))),
              ),
            ),
          ),
        ),
      );
      final declaredPrepared = ContourProcessorTestHarness.prepared;
      final renderBefore = key.currentContext!.findRenderObject();
      bool? preparedDuringBuild;
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
                  return const Text('Ordinary');
                },
              ),
            ),
          ),
        ),
      );
      final observed = (
        before,
        declaredPrepared,
        preparedDuringBuild,
        identical(renderBefore, key.currentContext!.findRenderObject()),
      );
      await unmountAndStop(tester);
      expect(observed, (false, false, true, true));
    },
    skip: kIsWeb,
  );

  testWidgets('when only the color changes, it should recolor the existing backing', (tester) async {
    final harness = ContourTestHarness();
    const child = CustomPaint(size: Size.square(40), painter: ContourTestPainter());
    await harness.mount(tester, amount: 4, child: child);
    await harness.mount(tester, color: const Color(0xFF0000FF), amount: 4, child: child);
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 28, 50), [0, 0, 255, 255]);
  });

  testWidgets('when density changes, it should regenerate a correctly positioned backing', (tester) async {
    final harness = ContourTestHarness();
    const child = CustomPaint(size: Size.square(40), painter: ContourTestPainter());
    await harness.mount(tester, amount: 4, child: child);
    await harness.mount(tester, pixelRatio: 3, amount: 2.5, child: child);
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 28, 50), [255, 255, 255, 255]);
  });
}
