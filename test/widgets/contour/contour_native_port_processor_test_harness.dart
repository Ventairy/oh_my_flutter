import 'dart:math' as math;
import 'dart:typed_data';

import 'package:oh_my_flutter/src/widgets/contour/contour.dart' show ContourProcessorTestHarness;
import 'package:oh_my_flutter/src/widgets/contour/contour_trace_admission.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_trace_policy.dart';

/// Exercises real processor admission, native retirement, and UI consumption.
final class ContourNativePortProcessorTestHarness {
  final _leases = <ContourTraceAdmissionLease>[];
  final _nativeLeases = <ContourTraceAdmissionLease>{};
  int _clients = 0;

  /// Reads process-global C state even while the processor closes its session.
  static ({
    int owners,
    int active,
    int jobs,
    int heldBytes,
    int nativeBytes,
    int calls,
  })
  get nativeState => (
    owners: ContourNativePortBindings.stat(1),
    active: ContourNativePortBindings.stat(3),
    jobs: ContourNativePortBindings.stat(13),
    heldBytes: ContourNativePortBindings.stat(4),
    nativeBytes: ContourNativePortBindings.stat(14),
    calls: ContourNativePortBindings.stat(15),
  );

  /// Avoids reusing the processor's diagnostic snapshot from the same microtask.
  static Future<Map<String, int>> snapshot() async {
    await Future<void>.value();
    return Map.of(ContourProcessorTestHarness.nativeTraceStats);
  }

  /// Attaches a client and prepares the Dart worker.
  void acquire() {
    ContourProcessorTestHarness.acquire();
    ContourProcessorTestHarness.prepare();
    _clients++;
  }

  /// Detaches one client while preserving caller-owned source leases.
  void releaseClient() {
    ContourProcessorTestHarness.release();
    _clients--;
  }

  /// Admits source bytes with only the production native metadata allowance.
  Future<ContourTraceAdmissionLease> admit({
    int width = 1024,
    int height = 512,
    int? legacyBytes,
    bool nativeTrace = true,
  }) async {
    final pixels = width * height;
    final cells = (width + 1) * (height + 1);
    final baselineBytes =
        legacyBytes ??
        pixels * 12 +
            (width + 2) * (height + 2) * 3 +
            math.min(4 * 1024 * 1024, cells * 144) * 3 +
            math.min(32768, cells * 2) * 128 +
            64 * 1024;
    final extra = nativeTrace ? ContourNativeTracePolicy.jobOverheadBytes : 0;
    final lease = await ContourProcessorTestHarness.admission
        .request(
          width: width,
          height: height,
          extraSourceBytes: extra,
          legacyBytes: baselineBytes + extra,
          owner: Object(),
        )
        .future;
    if (lease == null) throw StateError('The NativePort fixture was not admitted.');
    _leases.add(lease);
    if (extra > 0) _nativeLeases.add(lease);
    await until(
      () => ContourProcessorTestHarness.ready,
      'the unchanged prewarmed Dart worker',
    );
    return lease;
  }

  /// Supplies an opaque ring inside the actual admitted capture rectangle.
  static Uint8List coverage({int width = 1024, int height = 512}) {
    final rgba = Uint8List(width * height * 4);
    for (var y = 2; y < height - 2; y++) {
      for (var x = 2; x < width - 2; x++) {
        if (width == 16 && x >= 6 && x < 10 && y >= 6 && y < 10) continue;
        rgba[(y * width + x) * 4 + 3] = 255;
      }
    }
    return rgba;
  }

  /// Runs production native tracing with the caller's admitted ownership.
  Future<int?> trace(
    ContourTraceAdmissionLease lease, {
    int width = 1024,
    int height = 512,
  }) => ContourProcessorTestHarness.trace(
    coverage(width: width, height: height),
    width,
    height,
    lease: lease,
    nativeTrace: _nativeLeases.contains(lease),
  );

  /// Releases the UI consumption acknowledgment and its source reservation.
  void releaseLease(ContourTraceAdmissionLease lease) {
    lease.release();
    _leases.remove(lease);
    _nativeLeases.remove(lease);
  }

  /// Waits for observable lifecycle state without accepting a fixed delay.
  static Future<void> until(bool Function() ready, String phase) async {
    final clock = Stopwatch()..start();
    while (!ready()) {
      if (clock.elapsed > const Duration(seconds: 10)) throw StateError('NativePort processor did not reach $phase.');
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  /// Drains actual native cleanup before releasing every caller reservation.
  Future<void> finish() async {
    ContourProcessorTestHarness.nativePortTicket = null;
    while (_clients > 0) {
      releaseClient();
    }
    await ContourProcessorTestHarness.waitForStop().timeout(
      const Duration(seconds: 10),
    );
    for (final lease in _leases) {
      lease.release();
    }
    _leases.clear();
    _nativeLeases.clear();
    await until(
      () =>
          ContourProcessorTestHarness.activeNative == null &&
          ContourProcessorTestHarness.queuedNative == 0 &&
          ContourProcessorTestHarness.acknowledgements == 0 &&
          !ContourProcessorTestHarness.stopping &&
          ContourProcessorTestHarness.admission.activeSourceBytes == 0 &&
          ContourProcessorTestHarness.admission.activeScratchBytes == 0 &&
          ContourWorkBudget.shared.activeBytes == 0 &&
          ContourWorkBudget.shared.pendingCount == 0,
      'released processor and admission ownership',
    );
  }
}
