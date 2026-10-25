import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

void main() {
  testWidgets(
    'when the last web owner detaches during tracing, it should retain active capacity and discard queued payloads',
    (tester) async {
      final budget = ContourWorkBudget.shared;
      final firstKey = GlobalKey();
      final secondKey = GlobalKey();
      final replacementKey = GlobalKey();
      Widget source(GlobalKey key, double size) => Contour(
        key: key,
        color: const Color(0xFFFFFFFF),
        amount: 2,
        child: SizedBox.square(
          dimension: size,
          child: const ColoredBox(color: Color(0xFFFF0000)),
        ),
      );
      Widget scene(Widget child) => MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: child),
        ),
      );
      Object? diagnostic(RenderObject render, String name) =>
          render.toDiagnosticsNode().getProperties().firstWhere((property) => property.name == name).value;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          scene(Row(mainAxisSize: MainAxisSize.min, children: [source(firstKey, 200), source(secondKey, 200)])),
        );
        await tester.pump();
        final first = firstKey.currentContext!.findRenderObject()!;
        var observedQueue = false;
        for (var attempt = 0; attempt < 2000; attempt++) {
          if (diagnostic(first, 'webActiveCount') == 1 && (diagnostic(first, 'webQueuedPayloadBytes')! as int) > 0) {
            observedQueue = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        if (!observedQueue) throw StateError('The real browser tracer did not expose active and queued work.');
        final admittedBeforeDetach = budget.activeCount;
        await tester.pumpWidget(const SizedBox.shrink());
        await Future<void>.delayed(const Duration(milliseconds: 1));
        final activeAfterDetach = diagnostic(first, 'webActiveCount');
        final heldAfterDetach = budget.activeCount;
        final queuedAfterDetach = diagnostic(first, 'webQueuedPayloadBytes');

        await tester.pumpWidget(scene(source(replacementKey, 2)));
        await tester.pump();
        var maximumActive = 0;
        var drained = false;
        for (var attempt = 0; attempt < 4000; attempt++) {
          final active = diagnostic(first, 'webActiveCount')! as int;
          if (active > maximumActive) maximumActive = active;
          if (budget.activeCount == 0 && active == 0) {
            drained = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        if (!drained) throw StateError('Browser work did not drain after remounting.');
        await tester.pump();
        final replacementReady = diagnostic(replacementKey.currentContext!.findRenderObject()!, 'contourReady');
        await tester.pumpWidget(const SizedBox.shrink());
        // The shared workspace remains reserved alongside active sources.
        expect(
          (
            admittedBeforeDetach,
            activeAfterDetach,
            heldAfterDetach,
            queuedAfterDetach,
            maximumActive <= 1,
            replacementReady,
            budget.activeBytes,
          ),
          (3, 1, 2, 0, true, true, 0),
        );
      });
    },
    skip: !kIsWeb,
  );
}
