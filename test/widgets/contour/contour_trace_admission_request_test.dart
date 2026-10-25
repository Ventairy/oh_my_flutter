import 'package:flutter_test/flutter_test.dart';

import 'contour_trace_admission_test_harness.dart';

void main() {
  test(
    'when a source waits for payload capacity, it should cancel its reference without releasing another source',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final active = await harness.request(width: 4000, height: 700).future;
      final queued = harness.request(width: 1000, height: 1000)..cancel();
      final cancelled = await queued.future;
      final remaining = (
        cancelled,
        harness.admission.sharedCount,
        harness.budget.pendingCount,
        harness.budget.activeBytes,
      );
      active!.release();

      expect(
        (remaining, harness.budget.activeBytes),
        ((null, 1, 0, harness.admission.scratchBytes + active.bytes), 0),
      );
    },
  );

  test('when all sources cancel before a floor grant is delivered, it should release the old grant before a new cohort starts', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final cancelled = harness.request()..cancel();
    final replacement = harness.request();
    final first = await cancelled.future;
    final lease = await replacement.future;
    final active = (
      first,
      lease!.usesSharedScratch,
      harness.admission.sharedCount,
      harness.budget.activeBytes,
      harness.budget.activeCount,
    );
    lease.release();

    expect((active, harness.budget.activeBytes), ((null, true, 1, harness.admission.scratchBytes + 70336, 2), 0));
  });

  test(
    'when a cancelled floor already owns its grant, it should release it before a queued full legacy reservation',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final cancelled = harness.request()..cancel();
      final legacyRequest = harness.request(width: 4097, legacyBytes: harness.budget.maxBytes);
      final cancelledResult = await cancelled.future;
      final legacy = await legacyRequest.future;
      final active = (
        cancelledResult,
        legacy!.usesSharedScratch,
        harness.budget.activeBytes,
        harness.budget.activeCount,
      );
      legacy.release();

      expect((active, harness.budget.activeBytes), ((null, false, harness.budget.maxBytes, 1), 0));
    },
  );

  test(
    'when the legacy allowance exceeds total capacity, it should reject immediately without reserving a floor',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final lease = await harness.request(legacyBytes: harness.budget.maxBytes + 1).future;

      expect(
        (lease, harness.budget.activeBytes, harness.admission.sharedCount, harness.admission.legacyCount),
        (null, 0, 0, 0),
      );
    },
  );
}
