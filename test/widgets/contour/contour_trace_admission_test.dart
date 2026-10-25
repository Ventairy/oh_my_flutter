import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'contour_trace_admission_test_harness.dart';

void main() {
  test(
    'when native bookkeeping is requested, it should hold the extra source bytes until release',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final lease = await harness.admission
          .request(
            width: 20,
            height: 20,
            legacyBytes: 1024 * 1024 + 4096,
            extraSourceBytes: 4096,
            owner: Object(),
          )
          .future;
      final held = (lease!.bytes, harness.budget.activeBytes);
      lease.release();

      expect(
        (held, harness.budget.activeBytes),
        ((74432, harness.admission.scratchBytes + 74432), 0),
      );
    },
  );

  test(
    'when native bookkeeping uses legacy admission, it should reserve the complete allowance once',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final lease = await harness.admission
          .request(
            width: 4097,
            height: 20,
            legacyBytes: 1024 * 1024 + 4096,
            extraSourceBytes: 4096,
            owner: Object(),
          )
          .future;
      final held = (lease!.usesSharedScratch, lease.bytes, harness.budget.activeBytes);
      lease.release();

      expect((held, harness.budget.activeBytes), ((false, 1052672, 1052672), 0));
    },
  );

  test(
    'when a normal capture approaches the ceil allowance, it should share scratch only within the derived pixel cap',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final accepted = await harness.request(width: 4096, height: 769).future;
      final acceptedState = (accepted!.usesSharedScratch, harness.budget.activeBytes);
      accepted.release();
      // 4096 * 770 exceeds 3 Mi pixels + 8191 by exactly one pixel.
      final legacy = await harness.request(width: 4096, height: 770).future;
      final legacyState = (legacy!.usesSharedScratch, harness.budget.activeBytes);
      legacy.release();

      expect(
        (harness.admission.scratchBytes, acceptedState, legacyState, harness.budget.activeBytes),
        (26353673, (true, 64217097), (false, 1024 * 1024), 0),
      );
    },
  );

  test('when the first source requests capacity, it should reserve scratch before allowing its capture', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final request = harness.request();
    final beforeGrant = (harness.budget.activeBytes, harness.budget.activeCount, harness.admission.sharedCount);
    final lease = await request.future;
    final captureCapacity = (harness.budget.activeBytes, harness.budget.activeCount, lease!.bytes);
    lease.release();

    expect(
      (beforeGrant, captureCapacity, harness.budget.activeBytes),
      (
        (harness.admission.scratchBytes, 1, 1),
        (harness.admission.scratchBytes + 70336, 2, 70336),
        0,
      ),
    );
  });

  test('when forty small sources fit, it should admit all of them against one workspace', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final leases = await Future.wait([for (var index = 0; index < 40; index++) harness.request().future]);
    final admitted = (
      leases.where((lease) => lease?.usesSharedScratch ?? false).length,
      harness.admission.sharedCount,
      harness.budget.activeCount,
      harness.budget.pendingCount,
      harness.budget.activeBytes,
    );
    for (final lease in leases) {
      lease!.release();
    }

    expect(
      (
        admitted,
        harness.budget.activeBytes,
        harness.budget.activeCount,
        harness.admission.activeSourceBytes,
        harness.admission.peakScratchBytes,
        harness.admission.peakSourceBytes,
        harness.admission.peakSharedCount,
      ),
      (
        (40, 40, 41, 0, harness.admission.scratchBytes + 40 * 70336),
        0,
        0,
        0,
        harness.admission.scratchBytes,
        40 * 70336,
        40,
      ),
    );
  });

  test('when unsupported legacy work heads the queue, it should drain the cohort and floor before reserving legacy capacity', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final first = await harness.request().future;
    final legacyRequest = harness.request(width: 4097, legacyBytes: harness.budget.maxBytes);
    final laterRequest = harness.request();
    final beforeDrain = (
      harness.admission.sharedCount,
      harness.admission.legacyCount,
      harness.budget.pendingCount,
      harness.admission.deferredCount,
    );
    first!.release();
    final legacy = await legacyRequest.future;
    final legacyState = (
      legacy!.usesSharedScratch,
      harness.admission.sharedCount,
      harness.admission.legacyCount,
      harness.budget.activeBytes,
      harness.budget.activeCount,
    );
    legacy.release();
    final later = await laterRequest.future;
    final resumed = later!.usesSharedScratch;
    later.release();

    expect(
      (beforeDrain, legacyState, resumed, harness.budget.activeBytes),
      ((1, 0, 0, 2), (false, 0, 1, harness.budget.maxBytes, 1), true, 0),
    );
  });

  test(
    'when unrelated work is already admitted, it should use the legacy allowance without adding a phantom floor',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final unrelated = await harness.budget.request(bytes: 1024, owner: Object()).future;
      final lease = await harness.request(legacyBytes: 2048).future;
      final active = (lease!.usesSharedScratch, harness.budget.activeBytes, harness.budget.activeCount);
      lease.release();
      unrelated!.release();

      expect((active, harness.budget.activeBytes), ((false, 3072, 2), 0));
    },
  );

  test(
    'when two technical fallbacks fit together, it should still reserve their full allowances exclusively',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final firstRequest = harness.request(width: 4097, legacyBytes: 3 * 1024 * 1024);
      final secondRequest = harness.request(width: 4097, legacyBytes: 4 * 1024 * 1024);
      final first = await firstRequest.future;
      final firstAdmission = (
        first!.usesSharedScratch,
        harness.budget.activeBytes,
        harness.budget.activeCount,
        harness.admission.legacyCount,
      );
      first.release();
      final second = await secondRequest.future;
      final secondAdmission = (
        second!.usesSharedScratch,
        harness.budget.activeBytes,
        harness.budget.activeCount,
        harness.admission.legacyCount,
      );
      second.release();

      expect(
        (
          firstAdmission,
          secondAdmission,
          harness.budget.activeBytes,
          harness.admission.activeSourceBytes,
          harness.admission.peakScratchBytes,
          harness.admission.peakSourceBytes,
          harness.admission.peakSharedCount,
        ),
        ((false, 3 * 1024 * 1024, 1, 1), (false, 4 * 1024 * 1024, 1, 1), 0, 0, 0, 4 * 1024 * 1024, 0),
      );
    },
  );

  test('when worker shutdown outlives its acknowledged source, it should hold scratch until exit before admitting legacy work', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final exit = Completer<void>();
    final shared = await harness.request().future;
    harness.admission.retainScratchUntil(exit.future);
    shared!.release();
    final legacyRequest = harness.request(width: 4097, legacyBytes: harness.budget.maxBytes);
    final waiting = (harness.budget.activeBytes, harness.admission.sharedCount, harness.budget.pendingCount);
    exit.complete();
    final legacy = await legacyRequest.future;
    final afterExit = (legacy!.usesSharedScratch, harness.budget.activeBytes);
    legacy.release();

    expect(
      (waiting, afterExit, harness.budget.activeBytes),
      ((harness.admission.scratchBytes, 0, 0), (false, harness.budget.maxBytes), 0),
    );
  });

  test('when worker shutdown completes with an error, it should still return its workspace capacity', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final exit = Completer<void>();
    final shared = await harness.request().future;
    harness.admission.retainScratchUntil(exit.future);
    shared!.release();
    exit.completeError(StateError('worker exit'));
    await Future<void>.delayed(Duration.zero);

    expect((harness.budget.activeBytes, harness.budget.activeCount, harness.admission.sharedCount), (0, 0, 0));
  });
}
