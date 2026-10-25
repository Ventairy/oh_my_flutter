import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;
import 'package:oh_my_flutter/src/widgets/contour/contour_initial_frame_fence.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_native_proof_queue.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_native_test_harness.dart';

void main() {
  // Exercise the sampled fallback's glyph-proof queue and lifecycle.
  setUp(() => ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared);
  tearDown(() => ContourCompositeSource.testOverride = null);

  final budget = ContourWorkBudget.shared;
  final proofs = ContourNativeProofQueue.shared;

  Future<void> waitWithoutPumping(bool Function() condition, {required String phase}) async {
    for (var attempt = 0; attempt < 400; attempt++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('Contour did not reach $phase without another application frame.');
  }

  bool idle() =>
      !proofs.active &&
      proofs.pendingCount == 0 &&
      proofs.initialWorkCount == 0 &&
      budget.pendingCount == 0 &&
      budget.activeBytes == 0;

  Future<void> presentInitialGeometry(WidgetTester tester) async {
    final fence = ContourInitialFrameFence.shared;
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (fence.targetFrame >= 0 || fence.ready) break;
    }
    await waitWithoutPumping(
      () => fence.targetFrame >= 0 || fence.ready,
      phase: 'the fresh main frame becoming the initial geometry fence target',
    );
    if (fence.targetFrame >= 0) fence.reportRasterFinished(fence.targetFrame);
    await waitWithoutPumping(() => fence.ready, phase: 'the fresh initial geometry frame finishing rasterization');
  }

  Widget scene(
    ContourNativeTestHarness harness, {
    bool includeFollower = true,
    bool hideOwner = false,
    bool hideFollower = false,
    String followerText = 'O',
  }) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 2),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final key in [harness.firstKey, if (includeFollower) harness.secondKey])
              SizedBox.square(
                dimension: 100,
                child: Center(
                  child: Offstage(
                    offstage: key == harness.firstKey ? hideOwner : hideFollower,
                    child: Contour(
                      key: key,
                      color: const Color(0xFF000000),
                      amount: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          key == harness.secondKey ? followerText : 'O',
                          style: const TextStyle(
                            fontFamily: 'Ahem',
                            fontSize: 24,
                            height: 1,
                            color: Color(0xFFE84A5F),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  testWidgets(
    'when an offstage follower changes while its shared proof waits, it should finish with no pending native status',
    (tester) async {
      final harness = ContourNativeTestHarness();
      ContourWorkBudgetLease? blocker;
      addTearDown(() async {
        await tester.runAsync(() async {
          try {
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            blocker?.release();
          }
          await waitWithoutPumping(idle, phase: 'released proof and tracing resources during cleanup');
        });
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(scene(harness));
        await waitWithoutPumping(
          () =>
              harness.diagnostic('contourReady', key: harness.firstKey) == true &&
              harness.diagnostic('contourReady', key: harness.secondKey) == true &&
              harness.diagnostic('traceCaptureCount', key: harness.firstKey) == 1 &&
              harness.diagnostic('traceCaptureCount', key: harness.secondKey) == 0 &&
              harness.diagnostic('nativeTextStatus', key: harness.secondKey) == 'waiting' &&
              proofs.initialWorkCount == 0 &&
              proofs.pendingCount == 1 &&
              !proofs.active &&
              budget.activeBytes == 0,
          phase: 'shared generic geometry before either owner presents its contour',
        );

        blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
        await presentInitialGeometry(tester);
        await waitWithoutPumping(
          () => proofs.active && budget.pendingCount == 1,
          phase: 'the shared owner proof waiting behind the full foreground reservation',
        );

        // Offstage still lays out QQ, but omits this follower from composition.
        // Its shared proof callback must reject the old source and stop waiting
        // without relying on another composition to reset its diagnostic state.
        await tester.pumpWidget(scene(harness, hideFollower: true, followerText: 'QQ'));
        blocker!.release();
        await waitWithoutPumping(idle, phase: 'the original owner proof finishing without rendering its follower');
      });

      expect(
        (
          harness.diagnostic('nativeTextStatus', key: harness.secondKey),
          harness.diagnostic('generating', key: harness.secondKey),
          harness.diagnostic('nativeTextActive', key: harness.secondKey),
          proofs.pendingCount,
          proofs.active,
          proofs.initialWorkCount,
          budget.pendingCount,
          budget.activeBytes,
        ),
        ('unverified', false, false, 0, false, 0, 0, 0),
      );
    },
  );

  testWidgets(
    'when an unpresented owner goes offstage before its follower appears, it should finish their shared proof',
    (tester) async {
      final harness = ContourNativeTestHarness();
      addTearDown(() async {
        await tester.runAsync(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await waitWithoutPumping(idle, phase: 'released proof and tracing resources during cleanup');
        });
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(scene(harness, includeFollower: false));
        await waitWithoutPumping(
          () =>
              harness.diagnostic('contourReady', key: harness.firstKey) == true &&
              harness.diagnostic('traceCaptureCount', key: harness.firstKey) == 1 &&
              harness.diagnostic('firstPresentationFrameNumber', key: harness.firstKey) == -1 &&
              proofs.initialWorkCount == 0 &&
              proofs.pendingCount == 1 &&
              !proofs.active &&
              budget.activeBytes == 0,
          phase: 'the original owner publishing generic geometry without a main scene presentation',
        );

        // The new follower can display the shared generic contour immediately.
        // Its actual presentation must release the shared proof even though the
        // original owner never contributes a visible scene of its own.
        await tester.pumpWidget(scene(harness, hideOwner: true));
        await presentInitialGeometry(tester);
        await waitWithoutPumping(idle, phase: 'the presented follower releasing its hidden owner shared proof');
      });

      expect(
        (
          harness.diagnostic('firstPresentationFrameNumber', key: harness.firstKey),
          harness.diagnostic('firstPresentationHasContour', key: harness.secondKey),
          harness.diagnostic('generating', key: harness.firstKey),
          harness.diagnostic('generating', key: harness.secondKey),
          proofs.pendingCount,
          proofs.active,
          proofs.initialWorkCount,
          budget.pendingCount,
          budget.activeBytes,
        ),
        (-1, true, false, false, 0, false, 0, 0, 0),
      );
    },
  );
}
