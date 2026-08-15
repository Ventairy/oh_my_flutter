part of 'morph.dart';

final class _MorphRasterSnapshotScheduler<K, V> {
  _MorphRasterSnapshotScheduler(
    this._disposeValue, {
    required int maximumPending,
  }) : assert(
         maximumPending > 0,
         'A raster scheduler must admit at least one request.',
       ),
       _maximumPending = maximumPending;

  final int _maximumPending;
  final void Function(V value) _disposeValue;
  final Map<K, _MorphRasterSnapshotAdmission<K, V>> _running = <K, _MorphRasterSnapshotAdmission<K, V>>{};
  final Map<K, _MorphRasterSnapshotRetry<K>> _deferred = <K, _MorphRasterSnapshotRetry<K>>{};
  _MorphRasterSnapshotRetry<K>? _granted;
  int _generation = 0;
  int? _frameCallbackId;
  bool _admittedThisFrame = false;
  bool _disposed = false;
  int _starts = 0;
  int _lateDisposals = 0;

  int get debugRunningCount => _running.length;

  int get debugDeferredCount => _deferred.length;

  bool get debugHasScheduledFrame => _frameCallbackId != null;

  int get debugStartCount => _starts;

  int get debugLateDisposalCount => _lateDisposals;

  ({
    Future<V>? value,
    Future<bool>? retry,
    VoidCallback? cancelRetry,
    bool isNew,
  })?
  load(K key, Future<V> Function() loader) {
    // Never retain loader: a deferred caller must retry with its current,
    // request-local raster inputs after this scheduler grants admission.
    if (_disposed) return null;

    final running = _running[key];
    if (running != null) {
      return (
        value: running.completer.future,
        retry: null,
        cancelRetry: null,
        isNew: false,
      );
    }

    final granted = _granted;
    if (granted != null && granted.generation == _generation && granted.key == key) {
      _granted = null;
      return _start(key, loader);
    }

    final deferred = _deferred[key];
    if (deferred != null) return _retryResult(deferred);

    if (_outstandingUniqueCount >= _maximumPending) return null;

    if (_admittedThisFrame) {
      return _defer(key);
    }

    _admittedThisFrame = true;
    _scheduleFrame();
    return _start(key, loader);
  }

  void clear() {
    if (_disposed) return;
    _invalidate('The Morph raster request was cleared.');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _invalidate('The Morph raster scheduler was disposed.');
    final callbackId = _frameCallbackId;
    _frameCallbackId = null;
    if (callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callbackId);
    }
    _admittedThisFrame = false;
  }

  ({
    Future<V>? value,
    Future<bool>? retry,
    VoidCallback? cancelRetry,
    bool isNew,
  })
  _start(K key, Future<V> Function() loader) {
    _starts += 1;
    final admission = _MorphRasterSnapshotAdmission<K, V>(
      key: key,
      generation: _generation,
    );
    _running[key] = admission;
    late final Future<V> future;
    try {
      future = loader();
    } on Object catch (error, stackTrace) {
      _completeError(admission, error, stackTrace);
      return (
        value: admission.completer.future,
        retry: null,
        cancelRetry: null,
        isNew: true,
      );
    }
    unawaited(
      future.then(
        (value) => _completeValue(admission, value),
        onError: (Object error, StackTrace stackTrace) {
          _completeError(admission, error, stackTrace);
        },
      ),
    );
    return (
      value: admission.completer.future,
      retry: null,
      cancelRetry: null,
      isNew: true,
    );
  }

  ({
    Future<V>? value,
    Future<bool>? retry,
    VoidCallback? cancelRetry,
    bool isNew,
  })
  _defer(K key) {
    final retry = _MorphRasterSnapshotRetry<K>(
      key: key,
      generation: _generation,
    );
    _deferred[key] = retry;
    _ensureDrain();
    return _retryResult(retry);
  }

  ({
    Future<V>? value,
    Future<bool>? retry,
    VoidCallback? cancelRetry,
    bool isNew,
  })
  _retryResult(_MorphRasterSnapshotRetry<K> retry) {
    retry.waiters += 1;
    var active = true;
    void cancel() {
      if (!active) return;
      active = false;
      if (retry.completer.isCompleted) return;

      retry.waiters -= 1;
      if (retry.waiters != 0 || !identical(_deferred[retry.key], retry)) {
        return;
      }
      _deferred.remove(retry.key);
      retry.completer.complete(false);
      _cancelIdleFrame();
    }

    return (
      value: null,
      retry: retry.completer.future,
      cancelRetry: cancel,
      isNew: false,
    );
  }

  void _scheduleFrame({bool rescheduling = false}) {
    if (_disposed || _frameCallbackId != null) return;
    _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback(
      _handleFrame,
      rescheduling: rescheduling,
    );
  }

  void _handleFrame(Duration _) {
    _frameCallbackId = null;
    if (_disposed) return;

    _admittedThisFrame = false;
    _granted = null;
    if (_deferred.isEmpty || _running.length >= _maximumPending) return;

    final retry = _deferred.values.first;
    _deferred.remove(retry.key);
    if (retry.generation != _generation) {
      if (!retry.completer.isCompleted) retry.completer.complete(false);
      _ensureDrain();
      return;
    }
    _granted = retry;
    _admittedThisFrame = true;
    retry.completer.complete(true);
    _scheduleFrame(rescheduling: true);
  }

  void _completeValue(
    _MorphRasterSnapshotAdmission<K, V> admission,
    V value,
  ) {
    if (!_isCurrent(admission)) {
      _lateDisposals += 1;
      _disposeValueSafely(value);
      return;
    }

    _running.remove(admission.key);
    admission.completer.complete(value);
    _ensureDrain();
  }

  void _completeError(
    _MorphRasterSnapshotAdmission<K, V> admission,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!_isCurrent(admission)) return;

    _running.remove(admission.key);
    admission.completer.completeError(error, stackTrace);
    _ensureDrain();
  }

  bool _isCurrent(_MorphRasterSnapshotAdmission<K, V> admission) {
    return !_disposed && admission.generation == _generation && identical(_running[admission.key], admission);
  }

  int get _outstandingUniqueCount {
    return _running.length + _deferred.length + (_granted == null ? 0 : 1);
  }

  void _ensureDrain() {
    if (_disposed || _deferred.isEmpty || _running.length >= _maximumPending) {
      return;
    }
    _scheduleFrame();
  }

  void _cancelIdleFrame() {
    if (_deferred.isNotEmpty || _admittedThisFrame || _granted != null) return;

    final callbackId = _frameCallbackId;
    _frameCallbackId = null;
    if (callbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callbackId);
    }
  }

  void _invalidate(String message) {
    _generation += 1;
    _granted = null;
    _admittedThisFrame = false;

    final retries = _deferred.values.toList(growable: false);
    _deferred.clear();
    for (final retry in retries) {
      if (!retry.completer.isCompleted) retry.completer.complete(false);
    }

    final admissions = _running.values.toList(growable: false);
    _running.clear();
    for (final admission in admissions) {
      if (!admission.completer.isCompleted) {
        admission.completer.completeError(
          StateError(message),
          StackTrace.current,
        );
      }
    }
    _cancelIdleFrame();
  }

  void _disposeValueSafely(V value) {
    try {
      _disposeValue(value);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'oh_my_flutter Morph raster scheduler',
          context: ErrorDescription(
            'while disposing invalidated Morph raster work',
          ),
        ),
      );
    }
  }
}
