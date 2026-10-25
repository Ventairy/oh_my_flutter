import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_initial_frame_fence.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_shadow_pool_test_harness.dart';
import 'contour_solid_test_painter.dart';

void main() {
  testWidgets(
    'when a presented source refresh waits for memory, it should allow another presented contour to cache its shadow',
    (tester) async {
      final harness = ContourShadowPoolTestHarness();
      final fence = ContourInitialFrameFence.shared;
      final budget = ContourWorkBudget.shared;
      ContourWorkBudgetLease? blocker;
      addTearDown(() async {
        blocker?.release();
        blocker = null;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 400 && (budget.pendingCount != 0 || budget.activeBytes != 0); attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });
      });

      Future<void> mount({bool changed = false}) => harness.mount(
        tester,
        count: 2,
        settle: false,
        amountFor: (index) => changed && index == 1 ? 4 : 3,
        shadowsFor: (index) => [
          Shadow(
            color: const Color(0x33000000),
            blurRadius: 4,
            offset: Offset(changed && index == 1 ? 1.25 : .25, 2),
          ),
        ],
        childFor: (index) => SizedBox.square(
          dimension: 24,
          child: CustomPaint(
            painter: ContourSolidTestPainter(
              color: changed && index == 0 ? const Color(0xFF0000FF) : const Color(0xFFFF0000),
            ),
          ),
        ),
      );

      Future<void> finishRendering() async {
        for (var attempt = 0; attempt < 400; attempt++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          await tester.pump(const Duration(milliseconds: 1));
          // The test binding supplies no raster timing. Complete only the fresh
          // frame the shared fence actually submitted; foreground holds remain.
          if (fence.targetFrame >= 0) fence.reportRasterFinished(fence.targetFrame);
          if (harness.property('generating') == false &&
              harness.property('generating', 1) == false &&
              !tester.binding.hasScheduledFrame) {
            return;
          }
        }
        throw StateError('The presented contours did not finish rendering.');
      }

      await mount();
      await finishRendering();
      final initiallyReady = <Object?>[
        harness.property('firstPresentationHasContour'),
        harness.property('firstPresentationHasContour', 1),
        harness.property('shadowCacheReady'),
        harness.property('shadowCacheReady', 1),
      ];
      final firstCaptures = harness.property('traceCaptureCount');
      final secondCaptures = harness.property('traceCaptureCount', 1);
      final secondBuilds = harness.property('shadowCacheBuildCount', 1)! as int;
      final secondResource = harness.property('shadowResourceId', 1);
      final request = budget.request(bytes: budget.maxBytes, owner: Object());
      blocker = await tester.runAsync<ContourWorkBudgetLease?>(() => request.future);
      if (blocker == null) throw StateError('The full foreground reservation was not admitted.');

      await mount(changed: true);
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 400 && budget.pendingCount == 0; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      // The first trace remains causally blocked for this entire observation.
      // The second contour already has geometry and needs only a new shadow.
      await tester.pump(const Duration(milliseconds: 121));
      for (var attempt = 0; attempt < 200 && harness.property('shadowCacheReady', 1) != true; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump(const Duration(milliseconds: 1));
        if (fence.targetFrame >= 0) fence.reportRasterFinished(fence.targetFrame);
      }
      final whileRefreshIsBlocked = <Object?>[
        budget.activeBytes == budget.maxBytes,
        budget.pendingCount,
        harness.property('traceCaptureCount') == firstCaptures,
        harness.property('traceCaptureCount', 1) == secondCaptures,
        harness.property('contourReady', 1),
        harness.property('shadowCacheReady', 1),
        harness.property('shadowCacheBuildCount', 1) == secondBuilds + 1,
        harness.property('shadowResourceId', 1) != secondResource,
      ];
      blocker!.release();
      blocker = null;
      await finishRendering();
      expect(
        <Object?>[
          initiallyReady,
          whileRefreshIsBlocked,
          harness.property('contourReady'),
          harness.property('contourReady', 1),
          harness.property('shadowCacheReady'),
          harness.property('shadowCacheReady', 1),
          budget.pendingCount,
          budget.activeBytes,
        ],
        <Object?>[
          <Object?>[true, true, true, true],
          <Object?>[true, 1, true, true, true, true, true, true],
          true,
          true,
          true,
          true,
          0,
          0,
        ],
      );
    },
  );
}
