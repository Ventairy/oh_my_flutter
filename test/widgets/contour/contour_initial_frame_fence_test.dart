import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_initial_frame_fence.dart';

void main() {
  testWidgets('when a fresh frame is submitted, it should wait for that frame to finish rasterizing', (tester) async {
    final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10);
    bool? result;
    unawaited(fence.wait().then((value) => result = value));
    await tester.pump();
    final beforeRaster = [result, fence.ready, fence.targetFrame, fence.fenceCount];
    fence.reportRasterFinished(9);
    await tester.pump();
    final beforeTarget = [result, fence.ready];
    fence.reportRasterFinished(10);
    await tester.pump();
    expect(
      [beforeRaster, beforeTarget, result, fence.ready, fence.reason, fence.fallbackCount],
      [
        [null, false, 10, 1],
        [null, false],
        true,
        true,
        'raster',
        0,
      ],
    );
  });

  testWidgets('when geometry invalidates a successful epoch, it should require another fresh rasterized frame', (
    tester,
  ) async {
    var nextFrame = 10;
    final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => nextFrame++);
    final first = fence.wait();
    await tester.pump();
    fence.reportRasterFinished(10);
    await tester.pump();
    await first;
    fence.invalidateEpoch();
    final invalidated = [fence.ready, fence.epoch];
    final second = fence.wait();
    await tester.pump();
    fence.reportRasterFinished(11);
    await tester.pump();
    expect(
      [invalidated, await second, fence.fenceCount, fence.targetFrame],
      [
        [false, 1],
        true,
        2,
        11,
      ],
    );
  });

  testWidgets('when another waiter uses an already fenced epoch, it should reuse the successful fence', (tester) async {
    final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10);
    final first = fence.wait();
    await tester.pump();
    fence.reportRasterFinished(10);
    await tester.pump();
    await first;
    expect([await fence.wait(), fence.fenceCount, fence.reason], [true, 1, 'raster']);
  });

  testWidgets('when foreground work starts during frame submission, it should rearm after that work finishes', (
    tester,
  ) async {
    final submissions = <Completer<int>>[];
    final fence = ContourInitialFrameFence.test(
      submitFreshFrame: () {
        final submission = Completer<int>();
        submissions.add(submission);
        return submission.future;
      },
    );
    final ready = fence.wait();
    await tester.pump();
    fence.beginForeground();
    submissions.first.complete(10);
    await tester.pump();
    final whileActive = [fence.ready, fence.fenceCount, fence.epoch];
    fence.endForeground();
    await tester.pump();
    submissions.last.complete(11);
    await tester.pump();
    fence.reportRasterFinished(10);
    await tester.pump();
    final beforeFreshRaster = fence.ready;
    fence.reportRasterFinished(11);
    await tester.pump();
    expect(
      [whileActive, beforeFreshRaster, await ready, fence.fenceCount],
      [
        [false, 1, 1],
        false,
        true,
        2,
      ],
    );
  });

  testWidgets('when foreground work starts after submission, it should reject the earlier raster fence', (
    tester,
  ) async {
    var nextFrame = 10;
    final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => nextFrame++);
    final ready = fence.wait();
    await tester.pump();
    fence
      ..beginForeground()
      ..reportRasterFinished(10)
      ..endForeground();
    await tester.pump();
    final beforeFreshRaster = [fence.ready, fence.targetFrame];
    fence.reportRasterFinished(11);
    await tester.pump();
    expect(
      [beforeFreshRaster, await ready, fence.epoch, fence.fenceCount],
      [
        [false, 11],
        true,
        1,
        2,
      ],
    );
  });

  testWidgets('when one waiter is cancelled, it should wake immediately without cancelling the shared fence', (
    tester,
  ) async {
    final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10);
    final cancellation = Completer<void>();
    bool? first;
    bool? second;
    unawaited(fence.wait(cancelled: cancellation.future).then((value) => first = value));
    unawaited(fence.wait().then((value) => second = value));
    await tester.pump();
    cancellation.complete();
    await tester.pump();
    final afterCancellation = [first, second, fence.ready, fence.fenceCount];
    fence.reportRasterFinished(10);
    await tester.pump();
    expect(
      [afterCancellation, second, fence.ready, fence.fenceCount],
      [
        [false, null, false, 1],
        true,
        true,
        1,
      ],
    );
  });

  testWidgets(
    'when an already fenced caller is already cancelled, it should return cancellation without invalidating the fence',
    (tester) async {
      final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10);
      final first = fence.wait();
      await tester.pump();
      fence.reportRasterFinished(10);
      await tester.pump();
      await first;
      final cancellation = Completer<void>()..complete();
      expect([await fence.wait(cancelled: cancellation.future), fence.ready, fence.fenceCount], [false, true, 1]);
    },
  );

  testWidgets('when every pending waiter cancels, it should leave no fallback timer running', (tester) async {
    final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10);
    final cancellation = Completer<void>();
    final waiting = fence.wait(cancelled: cancellation.future);
    await tester.pump();
    cancellation.complete();
    await tester.pump();
    expect([await waiting, fence.ready, fence.fallbackCount], [false, false, 0]);
  });

  testWidgets('when multiple pending waiters all cancel, it should retire demand only after the final cancellation', (
    tester,
  ) async {
    final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10);
    final firstCancellation = Completer<void>();
    final secondCancellation = Completer<void>();
    final first = fence.wait(cancelled: firstCancellation.future);
    final second = fence.wait(cancelled: secondCancellation.future);
    await tester.pump();
    firstCancellation.complete();
    await tester.pump();
    final afterFirst = [await first, fence.waitingCount, fence.targetFrame];
    secondCancellation.complete();
    await tester.pump();
    expect(
      [afterFirst, await second, fence.waitingCount, fence.targetFrame],
      [
        [false, 1, 10],
        false,
        0,
        -1,
      ],
    );
  });

  testWidgets(
    'when new demand follows complete cancellation, it should submit a fresh frame instead of reviving the abandoned fence',
    (tester) async {
      var nextFrame = 10;
      final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => nextFrame++);
      final cancellation = Completer<void>();
      final abandoned = fence.wait(cancelled: cancellation.future);
      await tester.pump();
      cancellation.complete();
      await tester.pump();
      await abandoned;
      final waiting = fence.wait();
      await tester.pump();
      fence.reportRasterFinished(11);
      await tester.pump();
      expect([await waiting, fence.targetFrame, fence.fenceCount, fence.reason], [true, 11, 2, 'raster']);
    },
  );

  testWidgets(
    'when an abandoned frame submission finishes after new demand starts, it should not overwrite the new fence',
    (tester) async {
      final submissions = <Completer<int>>[];
      final fence = ContourInitialFrameFence.test(
        submitFreshFrame: () {
          final submission = Completer<int>();
          submissions.add(submission);
          return submission.future;
        },
      );
      final cancellation = Completer<void>();
      final abandoned = fence.wait(cancelled: cancellation.future);
      await tester.pump();
      cancellation.complete();
      await tester.pump();
      await abandoned;
      final waiting = fence.wait();
      await tester.pump();
      final submissionCount = submissions.length;
      final replacement = submissions.last;
      submissions.first.complete(10);
      await tester.pump();
      final afterObsoleteCompletion = [fence.ready, fence.targetFrame, fence.fenceCount, fence.waitingCount];
      if (!replacement.isCompleted) replacement.complete(11);
      await tester.pump();
      fence.reportRasterFinished(11);
      await tester.pump();
      expect(
        [submissionCount, afterObsoleteCompletion, await waiting, fence.targetFrame, fence.fenceCount],
        [
          2,
          [false, -1, 2, 1],
          true,
          11,
          2,
        ],
      );
    },
  );

  testWidgets(
    'when a backend returns an unsupported frame number, it should open after submission with an explicit fallback reason',
    (tester) async {
      final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => -1);
      final ready = fence.wait();
      await tester.pump();
      expect([await ready, fence.ready, fence.reason, fence.fallbackCount], [true, true, 'unsupportedFrameId', 1]);
    },
  );

  testWidgets('when a backend has never supplied timings, it should use the bounded fallback only after its timeout', (
    tester,
  ) async {
    final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10);
    bool? result;
    unawaited(fence.wait().then((value) => result = value));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));
    final beforeTimeout = [result, fence.ready];
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      [beforeTimeout, result, fence.ready, fence.reason, fence.fallbackCount],
      [
        [null, false],
        true,
        true,
        'timingsUnavailable',
        1,
      ],
    );
  });

  testWidgets(
    'when a backend has already supplied timings, it should never timeout while the target raster remains pending',
    (tester) async {
      final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10)..reportRasterFinished(1);
      final ready = fence.wait();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final whilePending = [fence.ready, fence.reason, fence.fallbackCount];
      fence.reportRasterFinished(10);
      await tester.pump();
      expect(
        [whilePending, await ready, fence.reason],
        [
          [false, null, 0],
          true,
          'raster',
        ],
      );
    },
  );

  testWidgets(
    'when timing support appears during the fallback wait, it should cancel that fallback until the target raster finishes',
    (tester) async {
      final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10);
      final ready = fence.wait();
      await tester.pump();
      fence.reportRasterFinished(1);
      await tester.pump(const Duration(seconds: 2));
      final whilePending = [fence.ready, fence.reason, fence.fallbackCount];
      fence.reportRasterFinished(10);
      await tester.pump();
      expect(
        [whilePending, await ready, fence.reason],
        [
          [false, null, 0],
          true,
          'raster',
        ],
      );
    },
  );

  testWidgets(
    'when foreground work is active before waiting, it should defer fresh frame submission until that work finishes',
    (tester) async {
      final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => 10)..beginForeground();
      final ready = fence.wait();
      await tester.pump();
      final whileActive = [fence.ready, fence.fenceCount];
      fence.endForeground();
      await tester.pump();
      fence.reportRasterFinished(10);
      await tester.pump();
      expect(
        [whileActive, await ready, fence.fenceCount],
        [
          [false, 0],
          true,
          1,
        ],
      );
    },
  );

  testWidgets(
    'when a later post-frame microtask starts foreground work, it should invalidate raster readiness before opening',
    (tester) async {
      var nextFrame = 10;
      final fence = ContourInitialFrameFence.test(submitFreshFrame: () async => nextFrame++);
      final ready = fence.wait();
      await tester.pump();
      tester.binding
        ..addPostFrameCallback((_) => fence.reportRasterFinished(10))
        ..addPostFrameCallback((_) => scheduleMicrotask(fence.beginForeground))
        ..scheduleFrame();
      await tester.pump();
      final afterCallbacks = [fence.ready, fence.epoch];
      fence.endForeground();
      await tester.pump();
      fence.reportRasterFinished(11);
      await tester.pump();
      expect(
        [afterCallbacks, await ready, fence.fenceCount],
        [
          [false, 1],
          true,
          2,
        ],
      );
    },
  );
}
