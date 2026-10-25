part of 'contour.dart';

class _ContourProcessor {
  static int _clients = 0;
  static int _nextId = 0;
  static Future<SendPort>? _worker;
  static _ContourWorkerLifecycle? _nativeGeneration;
  static Future<void>? _nativeStopping;
  static int _nativeEpoch = 0;
  static int _nativeStartCount = 0;
  static int _nativeExitCount = 0;
  static Future<void> Function(Isolate isolate)? _afterSpawnForTesting;
  static final _nativeQueue = Queue<_ContourWebWork>();
  static final _nativeWork = <int, _ContourWebWork>{};
  static int? _nativeActiveId;
  static ContourNativePortSession? _nativePortSession;
  static ContourNativePortSession? _nativePortClosingSession;
  static Map<String, int> _nativePortStatsAfterClose = const {};
  static bool _nativeTraceUsed = false;
  static int _dartTraceCalls = 0;
  static int _nativeQuotaFallbacks = 0;
  static int _nativeInitializationFallbacks = 0;
  static int _nativeSubmitFallbacks = 0;
  static int _nativeKernelFallbacks = 0;
  static int? _nativePortTicketForTesting;
  static Map<String, int>? _nativeStatsSnapshot;

  static bool get nativeTraceSupported => !kIsWeb && ContourNativePortSession.isSupported;
  static int get nativePortJobCount => nativeTraceStats['jobs'] ?? 0;
  static Map<String, int> get nativeTraceStats {
    if (_nativeStatsSnapshot case final snapshot?) return snapshot;
    final snapshot = <String, int>{
      if (_nativeTraceUsed) ...?(_nativePortSession ?? _nativePortClosingSession)?.stats,
      if (_nativeTraceUsed && _nativePortSession == null && _nativePortClosingSession == null)
        ..._nativePortStatsAfterClose,
      'dartTraces': _dartTraceCalls,
      'quotaFallbacks': _nativeQuotaFallbacks,
      'initializationFallbacks': _nativeInitializationFallbacks,
      'submitFallbacks': _nativeSubmitFallbacks,
      'kernelFallbacks': _nativeKernelFallbacks,
    };
    _nativeStatsSnapshot = snapshot;
    scheduleMicrotask(() => _nativeStatsSnapshot = null);
    return snapshot;
  }

  static final _awaitingAcknowledgements = <int, _ContourWebWork>{};
  static Future<void>? _webQueue;
  static final _webWork = <int, _ContourWebWork>{};
  static int? _webActiveId;
  static int _webActive = 0;
  static final _pending = <int, Completer<_ContourTraceResult?>>{};
  static final _verificationPending = <int, Completer<Map<String, int>?>>{};
  static final traceAdmission = ContourTraceAdmission(
    budget: ContourWorkBudget.shared,
    maximumPixels: _RenderContour._maximumPixels,
    maxGeometryBytes: _ContourTracer._maximumGeometryBytes,
    maxContourPoints: _ContourTracer._maximumContourPoints,
  );

  static int get webActiveCount => _webActive;
  static int get webQueuedPayloadBytes =>
      _webWork.values.where((work) => !work.active).fold<int>(0, (bytes, work) => bytes + work.payloadBytes);

  static void acquire() {
    _clients++;
  }

  static void prepare() {
    if (kIsWeb || _clients == 0 || _worker != null) return;
    final worker = _start();
    _worker = worker;
    unawaited(
      worker.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          if (identical(_worker, worker)) _worker = null;
        },
      ),
    );
  }

  static void release() {
    if (--_clients != 0) return;
    if (kIsWeb) {
      for (final work in _webWork.values.toList()) {
        work.cancelled = true;
        if (work.id == _webActiveId) continue;
        work.clearPayload();
        _webWork.remove(work.id);
        _pending.remove(work.id)?.complete();
        _verificationPending.remove(work.id)?.complete();
      }
      return;
    }
    _nativeEpoch++;
    final generation = _nativeGeneration;
    final legacyStopping = generation?.exited.future ?? _nativeStopping ?? Future<void>.value();
    final portSession = _nativePortSession;
    _nativePortSession = null;
    if (portSession != null) _nativePortClosingSession = portSession;
    final portStopping = portSession?.close().then((_) {
      _nativePortStatsAfterClose = portSession.stats;
      if (identical(_nativePortClosingSession, portSession)) _nativePortClosingSession = null;
    });
    final stopping = portStopping == null
        ? legacyStopping
        : Future.wait<void>([legacyStopping, portStopping]).then((_) {});
    // A reply may already have completed while its UI consumer is queued. Keep
    // the shared allowance until actual exit, independently of that UI ACK.
    traceAdmission.retainScratchUntil(stopping);
    final traces = _pending.keys.toList();
    final proofs = _verificationPending.keys.toList();
    if (generation != null) {
      generation.stopping = true;
      generation.responses.close();
      generation.isolate?.kill(priority: Isolate.immediate);
    }
    _nativeGeneration = null;
    _worker = null;
    _nativeStopping = stopping;
    for (final id in [...traces, ...proofs]) {
      final work = _nativeWork[id];
      if (work != null) {
        work
          ..cancelled = true
          ..clearPayload();
        _nativeQueue.remove(work);
      }
    }
    unawaited(
      stopping.then((_) {
        for (final id in traces) {
          _pending.remove(id)?.complete();
          _nativeResponseFinished(id);
        }
        for (final id in proofs) {
          _verificationPending.remove(id)?.complete();
          _nativeResponseFinished(id);
        }
        if (identical(_nativeStopping, stopping)) _nativeStopping = null;
      }),
    );
  }

  static Future<_ContourTraceResult?> trace(
    Uint8List rgba,
    int width,
    int height, {
    required double pixelRatio,
    ContourTraceAdmissionLease? admission,
    bool nativeTrace = false,
  }) {
    final id = _nextId++;
    assert(
      !nativeTrace || nativeTraceSupported && admission != null,
      'Native tracing requires support and admission.',
    );
    final completion = Completer<_ContourTraceResult?>();
    _pending[id] = completion;
    final work = _ContourWebWork.trace(
      id: id,
      rgba: rgba,
      width: width,
      height: height,
      ratio: pixelRatio,
      nativeTrace: nativeTrace,
      nativeTraceQuota: !nativeTrace
          ? 0
          : admission!.usesSharedScratch
          ? traceAdmission.scratchBytes + rgba.lengthInBytes * 2 + ContourNativeTracePolicy.jobOverheadBytes
          : admission.bytes - rgba.lengthInBytes,
    );
    if (admission?.usesSharedScratch ?? false) {
      work.acknowledgement = Completer<void>();
      _awaitingAcknowledgements[id] = work;
      admission!.bindAcknowledgement(() => _acknowledge(id));
    }
    if (kIsWeb) {
      _enqueueWeb(work);
    } else {
      _enqueueNative(work);
    }
    return completion.future;
  }

  static void _acknowledge(int id) {
    final work = _awaitingAcknowledgements.remove(id);
    final acknowledgement = work?.acknowledgement;
    if (acknowledgement != null && !acknowledgement.isCompleted) acknowledgement.complete();
    _finishNativeWork(id);
  }

  static void _enqueueNative(_ContourWebWork work) {
    _nativeWork[work.id] = work;
    _nativeQueue.addLast(work);
    _pumpNative();
  }

  static void _pumpNative() {
    if (_nativeActiveId != null || _nativeQueue.isEmpty) return;
    final work = _nativeQueue.removeFirst();
    _nativeActiveId = work.id;
    work.active = true;
    unawaited(_dispatchNativeWork(work));
  }

  static Future<void> _dispatchNativeWork(_ContourWebWork work) async {
    try {
      if (work.nativeTrace && await _dispatchPortWork(work)) return;
      final worker = await (_worker ??= _start());
      if (work.cancelled || !_pending.containsKey(work.id) && !_verificationPending.containsKey(work.id)) return;
      _liveGeneration(worker).pendingIds.add(work.id);
      if (work.verification) {
        worker.send((
          work.id,
          'verify',
          work.rgba!,
          work.width,
          work.height,
          work.ratio,
          work.original!,
          work.originalWidth,
          work.originalHeight,
          work.padding,
        ));
      } else {
        _dartTraceCalls++;
        worker.send((work.id, work.rgba!, work.width, work.height, work.ratio));
      }
      work.clearPayload();
    } catch (error, stack) {
      final traceCompletion = _pending.remove(work.id);
      final verificationCompletion = _verificationPending.remove(work.id);
      if (work.cancelled) {
        traceCompletion?.complete();
        verificationCompletion?.complete();
      } else {
        traceCompletion?.completeError(error, stack);
        verificationCompletion?.completeError(error, stack);
      }
      _nativeResponseFinished(work.id);
    }
  }

  static Future<bool> _dispatchPortWork(_ContourWebWork work) async {
    final stopping = _nativeStopping;
    if (stopping != null) await stopping;
    if (work.cancelled || !_pending.containsKey(work.id)) return true;
    var session = _nativePortSession;
    if (session == null) {
      try {
        session = ContourNativePortSession.create();
      } catch (_) {
        _nativeInitializationFallbacks++;
        return false;
      }
      if (session == null) {
        _nativeInitializationFallbacks++;
        return false;
      }
      _nativePortSession = session;
      _nativeTraceUsed = true;
    }
    final Future<ContourNativePortResult?> response;
    try {
      response = session.trace(
        work.rgba!,
        width: work.width,
        height: work.height,
        pixelRatio: work.ratio,
        totalQuota: work.nativeTraceQuota,
        ticket: _nativePortTicketForTesting,
      );
      _nativePortTicketForTesting = null;
    } catch (_) {
      _nativePortTicketForTesting = null;
      _nativeSubmitFallbacks++;
      return false;
    }
    final native = await response;
    if (native == null || work.cancelled || !_pending.containsKey(work.id)) {
      _pending.remove(work.id)?.complete();
      _nativeResponseFinished(work.id);
      return true;
    }
    work
      ..nativePortSession = session
      ..nativePortTicket = native.ticket;
    final _ContourTraceResult result;
    switch (native.status) {
      case 0:
        result = _ContourTraceResult.success(native.contours);
      case 1:
        result = const _ContourTraceResult.capacity();
      default:
        if (native.status == 4) _nativeQuotaFallbacks++;
        _nativeKernelFallbacks++;
        return false;
    }
    work.clearPayload();
    _pending.remove(work.id)?.complete(result);
    _nativeResponseFinished(work.id);
    return true;
  }

  static void _nativeResponseFinished(int id) {
    if (_nativeWork[id]?.acknowledgement == null) _finishNativeWork(id);
  }

  static void _finishNativeWork(int id) {
    final work = _nativeWork.remove(id);
    final nativeTicket = work?.nativePortTicket;
    if (nativeTicket != null) work?.nativePortSession?.ack(nativeTicket);
    work?.clearPayload();
    if (_nativeActiveId != id) return;
    _nativeActiveId = null;
    _pumpNative();
  }

  static Future<Map<String, int>?> verify(
    Uint8List rgba,
    int width,
    int height,
    double ratio,
    Uint8List original,
    int originalWidth,
    int originalHeight,
    int padding,
  ) {
    final id = _nextId++;
    final completion = Completer<Map<String, int>?>();
    _verificationPending[id] = completion;
    final work = _ContourWebWork.verification(
      id: id,
      rgba: rgba,
      width: width,
      height: height,
      ratio: ratio,
      original: original,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      padding: padding,
    );
    if (kIsWeb) {
      _enqueueWeb(work);
    } else {
      _enqueueNative(work);
    }
    return completion.future;
  }

  static void _enqueueWeb(_ContourWebWork work) {
    _webWork[work.id] = work;
    final next = (_webQueue ?? Future<void>.value()).then((_) => _runWeb(work));
    _webQueue = next;
    unawaited(
      next.then((_) {
        if (identical(_webQueue, next)) _webQueue = null;
      }),
    );
  }

  static Future<void> _runWeb(_ContourWebWork work) async {
    if (work.cancelled) return;
    work.active = true;
    _webActiveId = work.id;
    _webActive++;
    _ContourTraceResult? trace;
    Map<String, int>? verification;
    Object? error;
    StackTrace? stack;
    try {
      if (work.verification) {
        verification = await _ContourNativeVerification.check(
          work.rgba!,
          work.width,
          work.height,
          work.ratio,
          work.original!,
          work.originalWidth,
          work.originalHeight,
          work.padding,
        );
      } else {
        trace = await _ContourTracer.trace(
          work.rgba!,
          work.width,
          work.height,
          pixelRatio: work.ratio,
        );
      }
    } catch (caught, caughtStack) {
      error = caught;
      stack = caughtStack;
    } finally {
      work
        ..clearPayload()
        ..active = false;
      _webWork.remove(work.id);
      _webActiveId = null;
      _webActive--;
      final traceCompletion = _pending.remove(work.id);
      final verificationCompletion = _verificationPending.remove(work.id);
      if (work.cancelled) {
        traceCompletion?.complete();
        verificationCompletion?.complete();
      } else if (error != null) {
        traceCompletion?.completeError(error, stack);
        verificationCompletion?.completeError(error, stack);
      } else {
        traceCompletion?.complete(trace);
        verificationCompletion?.complete(verification);
      }
    }
    trace = null;
    verification = null;
    // A yielding web job is complete, but its result remains temporary until
    // the UI constructs geometry or discards it and releases the source lease.
    final acknowledgement = work.acknowledgement;
    if (acknowledgement != null) await acknowledgement.future;
  }

  static Future<SendPort> _start() async {
    final epoch = _nativeEpoch;
    final stopping = _nativeStopping;
    if (stopping != null) await stopping;
    if (_clients == 0 || epoch != _nativeEpoch) throw StateError('Contour worker start was cancelled.');
    final generation = _ContourWorkerLifecycle();
    _nativeGeneration = generation;
    unawaited(
      generation.ready.future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      ),
    );
    generation.responses.listen(
      (message) => _nativeResponse(generation, message),
    );
    generation.exits.listen((_) => _nativeExited(generation));
    Isolate? spawned;
    try {
      final isolate = await Isolate.spawn(
        _entry,
        generation.responses.sendPort,
        onExit: generation.exits.sendPort,
      );
      spawned = isolate;
      _nativeStartCount++;
      try {
        await _afterSpawnForTesting?.call(isolate);
      } catch (_) {
        generation.stopping = true;
        isolate.kill(priority: Isolate.immediate);
        await generation.exited.future;
        rethrow;
      }
      generation.isolate = isolate;
      if (generation.stopping ||
          generation.exited.isCompleted ||
          epoch != _nativeEpoch ||
          !identical(_nativeGeneration, generation)) {
        isolate.kill(priority: Isolate.immediate);
        await generation.exited.future;
        throw StateError('Contour worker stopped before dispatch was ready.');
      }
      return await generation.ready.future;
    } catch (error, stack) {
      if (!generation.exited.isCompleted && spawned == null) {
        generation.responses.close();
        generation.exits.close();
        generation.exited.complete();
      }
      if (!generation.ready.isCompleted) generation.ready.completeError(error, stack);
      if (identical(_nativeGeneration, generation)) {
        _nativeGeneration = null;
        _worker = null;
      }
      rethrow;
    }
  }

  static _ContourWorkerLifecycle _liveGeneration(SendPort port) {
    final generation = _nativeGeneration;
    if (generation == null || generation.stopping || generation.exited.isCompleted || generation.port != port) {
      throw StateError('Contour worker generation is no longer available.');
    }
    return generation;
  }

  static void _nativeResponse(
    _ContourWorkerLifecycle generation,
    Object? message,
  ) {
    if (generation.stopping) return;
    switch (message) {
      case final SendPort port:
        generation.port = port;
        if (!generation.ready.isCompleted) generation.ready.complete(port);
      case (final int id, final Map<String, int> result):
        generation.pendingIds.remove(id);
        _verificationPending.remove(id)?.complete(result);
        _nativeResponseFinished(id);
      case (final int id, final _ContourTraceResult result):
        generation.pendingIds.remove(id);
        _pending.remove(id)?.complete(result);
        _nativeResponseFinished(id);
      case (final int id, final String error, final String stack):
        generation.pendingIds.remove(id);
        _pending.remove(id)?.completeError(StateError(error), StackTrace.fromString(stack));
        _verificationPending.remove(id)?.completeError(StateError(error), StackTrace.fromString(stack));
        _nativeResponseFinished(id);
    }
  }

  static void _nativeExited(_ContourWorkerLifecycle generation) {
    generation.responses.close();
    generation.exits.close();
    _nativeExitCount++;
    if (!generation.ready.isCompleted) {
      generation.ready.completeError(
        StateError('Contour worker exited during startup.'),
      );
    }
    if (identical(_nativeGeneration, generation)) {
      _nativeGeneration = null;
      _worker = null;
    }
    for (final id in generation.pendingIds) {
      if (generation.stopping) {
        _pending.remove(id)?.complete();
        _verificationPending.remove(id)?.complete();
      } else {
        final error = StateError(
          'Contour worker exited before completing its work.',
        );
        _pending.remove(id)?.completeError(error);
        _verificationPending.remove(id)?.completeError(error);
      }
      _nativeResponseFinished(id);
    }
    generation.pendingIds.clear();
    // Actual exit owns the scratch hold. Notify waiters last because they may
    // synchronously admit the next generation after this cleanup is complete.
    if (!generation.exited.isCompleted) generation.exited.complete();
  }

  static void _entry(SendPort replies) {
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    requests.listen((message) async {
      if (message case (
        final int id,
        'verify',
        final Uint8List rgba,
        final int width,
        final int height,
        final double ratio,
        final Uint8List original,
        final int originalWidth,
        final int originalHeight,
        final int padding,
      )) {
        try {
          replies.send((
            id,
            await _ContourNativeVerification.check(
              rgba,
              width,
              height,
              ratio,
              original,
              originalWidth,
              originalHeight,
              padding,
            ),
          ));
        } catch (error, stack) {
          replies.send((id, error.toString(), stack.toString()));
        }
        return;
      }
      if (message case (
        final int id,
        final Uint8List rgba,
        final int width,
        final int height,
        final double pixelRatio,
      )) {
        try {
          final result = await _ContourTracer.trace(
            rgba,
            width,
            height,
            pixelRatio: pixelRatio,
          );
          replies.send((id, result));
        } catch (error, stack) {
          replies.send((id, error.toString(), stack.toString()));
        }
      }
    });
  }
}
