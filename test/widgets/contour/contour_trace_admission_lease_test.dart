import 'package:flutter_test/flutter_test.dart';

import 'contour_trace_admission_test_harness.dart';

void main() {
  test('when an admitted request is cancelled, it should retain capacity until its lease finishes', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final request = harness.request();
    final lease = await request.future;
    request.cancel();
    final beforeRelease = (harness.budget.activeBytes, harness.admission.sharedCount);
    lease!.release();

    expect((beforeRelease, harness.budget.activeBytes), ((harness.admission.scratchBytes + lease.bytes, 1), 0));
  });

  test(
    'when a lease releases repeatedly, it should acknowledge once before returning source and workspace capacity',
    () async {
      final harness = ContourTraceAdmissionTestHarness();
      final lease = await harness.request().future;
      var acknowledgements = 0;
      var acknowledgedBytes = 0;
      lease!
        ..bindAcknowledgement(() {
          acknowledgements++;
          acknowledgedBytes = harness.budget.activeBytes;
        })
        ..release()
        ..release();

      expect(
        (acknowledgements, acknowledgedBytes, harness.budget.activeBytes, harness.admission.sharedCount),
        (1, harness.admission.scratchBytes + lease.bytes, 0, 0),
      );
    },
  );

  test('when acknowledgement throws, it should still release all reserved capacity exactly once', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final lease = await harness.request().future;
    var acknowledgements = 0;
    Object? error;
    lease!.bindAcknowledgement(() {
      acknowledgements++;
      throw StateError('acknowledgement');
    });
    try {
      lease.release();
    } on Object catch (caught) {
      error = caught;
    }
    lease.release();

    expect(
      (acknowledgements, error is StateError, harness.budget.activeBytes, harness.admission.sharedCount),
      (1, true, 0, 0),
    );
  });

  test('when acknowledgement is bound twice, it should diagnose the invalid developer contract', () async {
    final harness = ContourTraceAdmissionTestHarness();
    final lease = await harness.request().future;
    lease!.bindAcknowledgement(() {});
    addTearDown(lease.release);

    expect(() => lease.bindAcknowledgement(() {}), throwsAssertionError);
  });
}
