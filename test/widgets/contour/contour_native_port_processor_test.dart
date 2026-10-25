@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart' show ContourProcessorTestHarness;
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

import 'contour_native_port_processor_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final supported = ContourNativePortSession.isSupported;

  test('when a source uses Dart tracing, it should preserve worker prewarming without opening a native port', () async {
    final harness = ContourNativePortProcessorTestHarness();
    addTearDown(harness.finish);
    final before = await ContourNativePortProcessorTestHarness.snapshot();
    final starts = ContourProcessorTestHarness.starts;
    harness.acquire();
    final lease = await harness.admit(
      width: 16,
      height: 16,
      nativeTrace: false,
    );
    final result = await harness.trace(lease, width: 16, height: 16).timeout(const Duration(seconds: 10));
    final replied = await ContourNativePortProcessorTestHarness.snapshot();
    harness.releaseLease(lease);
    await harness.finish();
    expect(
      (
        result != null && result > 0,
        (replied['calls'] ?? 0) - (before['calls'] ?? 0),
        replied['dartTraces']! - before['dartTraces']!,
        ContourProcessorTestHarness.starts - starts,
        lease.bytes,
        replied['initialized'] ?? 0,
        ContourWorkBudget.shared.activeBytes,
      ),
      (true, 0, 1, 1, 68608, 0, 0),
    );
  }, skip: !supported);

  test('when an admitted large native trace returns, it should produce C geometry while preserving the Dart worker prewarm', () async {
    final harness = ContourNativePortProcessorTestHarness();
    addTearDown(harness.finish);
    final before = await ContourNativePortProcessorTestHarness.snapshot();
    final starts = ContourProcessorTestHarness.starts;
    harness.acquire();
    final lease = await harness.admit();
    final result = await harness.trace(lease).timeout(const Duration(seconds: 10));
    final replied = await ContourNativePortProcessorTestHarness.snapshot();
    final awaiting = (
      ContourProcessorTestHarness.acknowledgements,
      replied['jobs'],
      replied['nativeOutAndWorkspaceBytes'],
    );
    harness.releaseLease(lease);
    await harness.finish();
    final after = ContourNativePortProcessorTestHarness.nativeState;
    expect(
      (
        result != null && result > 0,
        replied['calls']! - (before['calls'] ?? 0),
        replied['dartTraces']! - before['dartTraces']!,
        ContourProcessorTestHarness.starts - starts,
        lease.bytes,
        awaiting,
        after.jobs,
        after.heldBytes,
        after.nativeBytes,
        ContourWorkBudget.shared.activeBytes,
      ),
      (true, 1, 0, 1, 6361088, (1, 1, 0), 0, 0, 0, 0),
    );
  }, skip: !supported);

  test(
    'when a native source retains its UI lease, it should prevent the next Dart dispatch until acknowledgment',
    () async {
      final harness = ContourNativePortProcessorTestHarness();
      addTearDown(harness.finish);
      final before = await ContourNativePortProcessorTestHarness.snapshot();
      harness.acquire();
      final firstLease = await harness.admit();
      final secondLease = await harness.admit(
        width: 16,
        height: 16,
        nativeTrace: false,
      );
      final first = await harness.trace(firstLease).timeout(const Duration(seconds: 10));
      var secondFinished = false;
      final secondFuture = harness.trace(secondLease, width: 16, height: 16).whenComplete(() => secondFinished = true);
      await ContourNativePortProcessorTestHarness.until(
        () => ContourProcessorTestHarness.queuedNative == 1,
        'queued second source',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final blockedStats = await ContourNativePortProcessorTestHarness.snapshot();
      final blocked = (
        secondFinished,
        blockedStats['calls']! - (before['calls'] ?? 0),
        ContourProcessorTestHarness.queuedNative,
        ContourProcessorTestHarness.acknowledgements,
        ContourProcessorTestHarness.admission.activeSourceBytes,
      );
      harness.releaseLease(firstLease);
      final second = await secondFuture.timeout(const Duration(seconds: 10));
      final replied = await ContourNativePortProcessorTestHarness.snapshot();
      harness.releaseLease(secondLease);
      await harness.finish();
      expect(
        (
          first != null && first > 0,
          blocked,
          second != null && second > 0,
          replied['calls']! - (before['calls'] ?? 0),
          replied['dartTraces']! - before['dartTraces']!,
          ContourWorkBudget.shared.activeBytes,
        ),
        (
          true,
          (false, 1, 1, 2, firstLease.bytes + secondLease.bytes),
          true,
          1,
          1,
          0,
        ),
      );
    },
    skip: !supported,
  );

  test(
    'when technical dimensions use an exclusive source lease, it should acknowledge the C ticket on result completion',
    () async {
      final harness = ContourNativePortProcessorTestHarness();
      addTearDown(harness.finish);
      final before = await ContourNativePortProcessorTestHarness.snapshot();
      harness.acquire();
      final lease = await harness.admit(
        width: 4097,
        height: 128,
        legacyBytes: 24 * 1024 * 1024,
      );
      final result = await harness.trace(lease, width: 4097, height: 128).timeout(const Duration(seconds: 10));
      final replied = await ContourNativePortProcessorTestHarness.snapshot();
      final beforeRelease = (
        lease.usesSharedScratch,
        ContourProcessorTestHarness.acknowledgements,
        ContourProcessorTestHarness.admission.activeSourceBytes,
        replied['jobs'],
        replied['heldBytes'],
        replied['nativeOutAndWorkspaceBytes'],
        ContourProcessorTestHarness.activeNative,
      );
      harness.releaseLease(lease);
      await harness.finish();
      expect(
        (
          result != null && result > 0,
          replied['calls']! - (before['calls'] ?? 0),
          replied['status0']! - (before['status0'] ?? 0),
          replied['dartTraces']! - before['dartTraces']!,
          beforeRelease,
          ContourWorkBudget.shared.activeBytes,
        ),
        (true, 1, 1, 0, (false, 0, 24 * 1024 * 1024 + 4096, 0, 0, 0, null), 0),
      );
    },
    skip: !supported,
  );
  test('when copied native geometry is checked against Dart, it should match every coordinate bit after sequential execution', () async {
    final harness = ContourNativePortProcessorTestHarness();
    addTearDown(harness.finish);
    harness.acquire();
    final lease = await harness.admit();
    final rgba = ContourNativePortProcessorTestHarness.coverage();
    final session = ContourNativePortSession.create()!;
    addTearDown(session.close);
    final native = await session.trace(
      rgba,
      width: 1024,
      height: 512,
      pixelRatio: 3,
      totalQuota: ContourProcessorTestHarness.admission.scratchBytes + rgba.lengthInBytes * 2 + 4096,
    );
    session.ack(native!.ticket);
    await session.close();
    final retired = session.stats;
    final reference = await ContourProcessorTestHarness.traceContours(
      rgba,
      1024,
      512,
      lease: lease,
    );
    harness.releaseLease(lease);
    await harness.finish();
    expect(
      [
        native.status,
        retired['jobs'],
        retired['nativeOutAndWorkspaceBytes'],
        [
          for (final curve in native.contours) curve.buffer.asUint64List(curve.offsetInBytes, curve.length).toList(),
        ],
        ContourWorkBudget.shared.activeBytes,
      ],
      [
        0,
        0,
        0,
        [
          for (final curve in reference!) curve.buffer.asUint64List(curve.offsetInBytes, curve.length).toList(),
        ],
        0,
      ],
    );
  }, skip: !supported);

  test('when native submission is unavailable, it should complete through the prewarmed Dart worker and release the source', () async {
    final harness = ContourNativePortProcessorTestHarness();
    addTearDown(harness.finish);
    harness.acquire();
    final firstLease = await harness.admit();
    await harness.trace(firstLease);
    harness.releaseLease(firstLease);
    await ContourProcessorTestHarness.closeNativePort();
    final before = await ContourNativePortProcessorTestHarness.snapshot();
    final fallbackLease = await harness.admit();
    final result = await harness.trace(fallbackLease);
    final after = await ContourNativePortProcessorTestHarness.snapshot();
    harness.releaseLease(fallbackLease);
    await harness.finish();
    expect(
      (
        result != null && result > 0,
        after['calls']! - before['calls']!,
        after['dartTraces']! - before['dartTraces']!,
        after['submitFallbacks']! - before['submitFallbacks']!,
        after['jobs'],
        ContourWorkBudget.shared.activeBytes,
      ),
      (true, 0, 1, 1, 0, 0),
    );
  }, skip: !supported);
}
