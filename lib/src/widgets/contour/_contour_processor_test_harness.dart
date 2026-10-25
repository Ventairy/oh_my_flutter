part of 'contour.dart';

/// Exercises acknowledged trace lifecycle boundaries in focused regression tests.
@visibleForTesting
class ContourProcessorTestHarness {
  new _();

  /// Attaches one synthetic processing client.
  static void acquire() => _ContourProcessor.acquire();

  /// Detaches one synthetic processing client.
  static void release() => _ContourProcessor.release();

  /// Starts the optional native worker without allocating a source.
  static void prepare() => _ContourProcessor.prepare();

  /// Reports whether native worker preparation was requested before capture.
  static bool get prepared => _ContourProcessor._worker != null;

  /// Counts native worker starts for generation isolation assertions.
  static int get starts => _ContourProcessor._nativeStartCount;

  /// Counts actual native exit notifications.
  static int get exits => _ContourProcessor._nativeExitCount;

  /// Counts replies whose source lease still owns temporary geometry.
  static int get acknowledgements => _ContourProcessor._awaitingAcknowledgements.length;

  /// Counts native jobs waiting behind an active computation or acknowledgement.
  static int get queuedNative => _ContourProcessor._nativeQueue.length;

  /// Identifies the native serial slot, including a reply awaiting consumption.
  static int? get activeNative => _ContourProcessor._nativeActiveId;

  /// Reports whether a previous native generation has not exited yet.
  static bool get stopping => _ContourProcessor._nativeStopping != null;

  /// Counts active web computations.
  static int get webActive => _ContourProcessor.webActiveCount;

  /// Counts bytes retained by queued web payloads.
  static int get webQueuedBytes => _ContourProcessor.webQueuedPayloadBytes;

  /// Exposes isolated weighted admission diagnostics.
  static ContourTraceAdmission get admission => _ContourProcessor.traceAdmission;

  /// Delays assigning a spawned worker handle to reproduce last-client races.
  static Future<void> Function(Isolate isolate)? get afterSpawn => _ContourProcessor._afterSpawnForTesting;

  /// Installs a controlled startup barrier without changing dispatch ordering.
  static set afterSpawn(Future<void> Function(Isolate isolate)? callback) =>
      _ContourProcessor._afterSpawnForTesting = callback;

  /// Reports when the current worker has sent its ready port.
  static bool get ready => _ContourProcessor._nativeGeneration?.ready.isCompleted ?? false;

  /// Waits until any retiring native generation has actually exited.
  static Future<void> waitForStop() async {
    await _ContourProcessor._nativeStopping;
  }

  /// Runs separately admitted verification through the same worker ordering barrier.
  static Future<bool> verifyEmpty() async {
    final result = await _ContourProcessor.verify(
      Uint8List(16 * 16 * 5 * 4),
      16,
      16,
      3,
      Uint8List(12 * 12 * 4),
      12,
      12,
      2,
    );
    return result != null;
  }

  /// Reads native tracing counters without loading an unused native backend.
  static Map<String, int> get nativeTraceStats => _ContourProcessor.nativeTraceStats;

  /// Counts strongly retained native jobs awaiting copied replies or real exit.
  static int get nativePortJobCount => _ContourProcessor.nativePortJobCount;

  /// Uses a pre-armed native-port ticket for the next test trace.
  static int? get nativePortTicket => _ContourProcessor._nativePortTicketForTesting;

  /// Uses a pre-armed native-port ticket for the next test trace.
  static set nativePortTicket(int? ticket) => _ContourProcessor._nativePortTicketForTesting = ticket;

  /// Lists tickets still awaiting native result retirement or cancellation.
  static List<int> get nativePortPendingTickets =>
      _ContourProcessor._nativePortSession?.pendingTickets.toList() ?? const [];

  /// Closes the existing native session to exercise submission fallback safely.
  static Future<void> closeNativePort() async {
    await _ContourProcessor._nativePortSession?.close();
  }

  /// Traces test coverage while preserving the caller-owned consumption lease.
  static Future<int?> trace(
    Uint8List rgba,
    int width,
    int height, {
    ContourTraceAdmissionLease? lease,
    bool nativeTrace = false,
  }) async {
    final contours = await traceContours(
      rgba,
      width,
      height,
      lease: lease,
      nativeTrace: nativeTrace,
    );
    return contours?.fold<int>(0, (sum, curve) => sum + curve.lengthInBytes);
  }

  /// Returns copied backend coordinates for sequential reference comparisons.
  static Future<List<Float64List>?> traceContours(
    Uint8List rgba,
    int width,
    int height, {
    ContourTraceAdmissionLease? lease,
    bool nativeTrace = false,
  }) async {
    final result = await _ContourProcessor.trace(
      rgba,
      width,
      height,
      pixelRatio: 3,
      admission: lease,
      nativeTrace: nativeTrace,
    );
    return result?.contours;
  }
}
