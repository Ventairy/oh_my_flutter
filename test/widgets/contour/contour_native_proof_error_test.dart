import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;
import 'package:oh_my_flutter/src/widgets/contour/contour_initial_frame_fence.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_native_proof_queue.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_native_test_harness.dart';
import 'contour_native_throwing_feature.dart';

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

  Widget scene(ContourNativeTestHarness harness, ContourNativeThrowingFeature feature) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 2),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final key in [harness.firstKey, harness.secondKey])
              SizedBox.square(
                dimension: 100,
                child: Center(
                  child: Contour(
                    key: key,
                    color: const Color(0xFF000000),
                    amount: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        'O',
                        style: TextStyle(
                          fontFamily: 'Ahem',
                          fontSize: 24,
                          height: 1,
                          color: const Color(0xFFE84A5F),
                          fontFeatures: [feature],
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
    'when native proof and its error reporter fail, it should resolve shared subscribers to their generic contour',
    (tester) async {
      final harness = ContourNativeTestHarness();
      final feature = ContourNativeThrowingFeature();
      final previousErrorHandler = FlutterError.onError;
      ContourWorkBudgetLease? blocker;
      var reportedContourErrors = 0;
      addTearDown(() async {
        feature.armOneRead = false;
        FlutterError.onError = previousErrorHandler;
        await tester.runAsync(() async {
          try {
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            blocker?.release();
            await waitWithoutPumping(idle, phase: 'released proof and tracing resources during cleanup');
          }
        });
      });

      try {
        await tester.runAsync(() async {
          await tester.pumpWidget(scene(harness, feature));
          await waitWithoutPumping(
            () =>
                harness.diagnostic('contourReady', key: harness.firstKey) == true &&
                harness.diagnostic('contourReady', key: harness.secondKey) == true &&
                harness.diagnostic('traceCaptureCount', key: harness.firstKey) == 1 &&
                harness.diagnostic('traceCaptureCount', key: harness.secondKey) == 0 &&
                harness.diagnostic('firstPresentationFrameNumber', key: harness.firstKey) == -1 &&
                harness.diagnostic('firstPresentationFrameNumber', key: harness.secondKey) == -1 &&
                harness.diagnostic('nativeTextVerificationCount', key: harness.firstKey) == 0 &&
                harness.diagnostic('nativeTextVerificationCount', key: harness.secondKey) == 0 &&
                harness.diagnostic('nativeTextStatus', key: harness.secondKey) == 'waiting' &&
                proofs.initialWorkCount == 0 &&
                proofs.pendingCount == 1 &&
                !proofs.active &&
                budget.activeBytes == 0,
            phase: 'shared generic geometry before the first paired presentation and native proof',
          );

          blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
          await presentInitialGeometry(tester);
          await waitWithoutPumping(
            () => proofs.active && budget.pendingCount == 1,
            phase: 'the shared proof waiting for memory after its fresh frame is fenced',
          );

          // Only native verification needs to build another glyph painter.
          // The one-shot read then recovers so the follower can safely validate
          // its unchanged source after the shared error fallback completes.
          // Arm after the fresh frame so composition cannot consume the read.
          feature.armOneRead = true;
          FlutterError.onError = (details) {
            if (details.library != 'Contour') {
              previousErrorHandler?.call(details);
              return;
            }
            reportedContourErrors++;
            throw StateError('The Contour error reporter also failed.');
          };
          blocker!.release();
          await waitWithoutPumping(idle, phase: 'the failing shared proof releasing all queue and memory resources');
        });
      } finally {
        feature.armOneRead = false;
        FlutterError.onError = previousErrorHandler;
      }

      expect(
        (
          reportedContourErrors > 0,
          harness.diagnostic('nativeTextStatus', key: harness.firstKey),
          harness.diagnostic('nativeTextStatus', key: harness.secondKey),
          harness.diagnostic('nativeTextActive', key: harness.firstKey),
          harness.diagnostic('nativeTextActive', key: harness.secondKey),
          harness.diagnostic('generating', key: harness.firstKey),
          harness.diagnostic('generating', key: harness.secondKey),
          proofs.pendingCount,
          proofs.active,
          proofs.initialWorkCount,
          budget.pendingCount,
          budget.activeBytes,
        ),
        (true, 'error', 'rejected-shared', false, false, false, false, 0, false, 0, 0, 0),
      );
    },
  );
}
