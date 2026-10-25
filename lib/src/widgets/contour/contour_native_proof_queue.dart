import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Defers optional native glyph verification until initial contours are ready.
@internal
class ContourNativeProofQueue {
  new _({required int maximumPending})
    : _maximumPending = maximumPending,
      assert(maximumPending >= 0, 'The pending proof limit must be nonnegative.');

  /// Creates an isolated queue with a deterministic waiting capacity.
  @visibleForTesting
  new test({int maximumPending = 64}) : this._(maximumPending: maximumPending);

  /// The proof queue shared by contour renderers in the current isolate.
  static final ContourNativeProofQueue shared = ContourNativeProofQueue._(maximumPending: 64);

  final int _maximumPending;
  final _pending =
      LinkedHashMap<Object, ({Future<void> Function() run, VoidCallback onCancel, bool Function()? canRun})>.identity();
  int _initialWorkCount = 0;
  int _buildCount = 0;
  int _maximumInitialWorkAtStart = 0;
  bool _scheduled = false;
  bool _active = false;
  Object? _activeOwner;
  VoidCallback? _activeOnCancel;

  /// The number of initial contour operations that have not called [endInitial].
  int get initialWorkCount => _initialWorkCount;

  /// The number of proofs waiting behind initial or active work.
  int get pendingCount => _pending.length;

  /// Whether a started proof's future has not finished, including after cancellation.
  bool get active => _active;

  /// The number of proof callbacks started since this queue was created.
  int get buildCount => _buildCount;

  /// The highest initial-work count observed when a proof started.
  int get maximumInitialWorkAtStart => _maximumInitialWorkAtStart;

  /// Blocks new proofs until every matching [endInitial] call completes.
  ///
  /// A proof that has already started retains its active slot until its future
  /// finishes; initial work does not interrupt it.
  void beginInitial() {
    _initialWorkCount++;
  }

  /// Finishes one initial contour operation and allows waiting proofs to resume.
  void endInitial() {
    assert(_initialWorkCount > 0, 'Every initial completion must have a matching start.');
    _initialWorkCount--;
    _scheduleDrain();
  }

  /// Starts [run] when initial work and earlier proofs have finished.
  ///
  /// Returns `false` when the waiting queue is full or this exact [owner] object
  /// already has accepted work. Rejected work does not invoke [onCancel].
  /// Owners that compare equal remain independent unless they are identical.
  ///
  /// Accepted cancellation invokes [onCancel] once. Cancelling active work
  /// releases its callbacks, but its future must still finish before another
  /// proof can start. The owner may enqueue replacement work after cancellation.
  ///
  /// A false [canRun] result keeps this proof waiting while later ready proofs
  /// may proceed. The predicate must only inspect readiness. Call [wake] after
  /// readiness changes; an unready proof does not retry automatically.
  /// A throwing predicate cancels its proof and reports the failure through
  /// [FlutterError].
  bool enqueue({
    required Object owner,
    required Future<void> Function() run,
    required VoidCallback onCancel,
    bool Function()? canRun,
  }) {
    if (_pending.length >= _maximumPending || _pending.containsKey(owner) || identical(_activeOwner, owner)) {
      return false;
    }
    _pending[owner] = (run: run, onCancel: onCancel, canRun: canRun);
    _scheduleDrain();
    return true;
  }

  /// Rechecks waiting proofs after an external readiness change.
  void wake() {
    _scheduleDrain();
  }

  /// Cancels accepted work belonging to this exact [owner] object.
  ///
  /// Pending work releases its waiting slot immediately. Active work releases
  /// its serial slot only when its already-running future finishes.
  void cancel(Object owner) {
    final pending = _pending.remove(owner);
    if (pending != null) _notifyCancelled(pending.onCancel);
    if (identical(_activeOwner, owner)) {
      final callback = _activeOnCancel;
      _activeOwner = null;
      _activeOnCancel = null;
      if (callback != null) _notifyCancelled(callback);
    }
    _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_scheduled || _active || _initialWorkCount > 0 || _pending.isEmpty) return;
    _scheduled = true;
    scheduleMicrotask(_drain);
  }

  void _drain() {
    _scheduled = false;
    if (_active || _initialWorkCount > 0 || _pending.isEmpty) return;
    Object? owner;
    for (final entry in _pending.entries) {
      bool ready;
      try {
        ready = entry.value.canRun?.call() ?? true;
      } catch (error, stack) {
        _pending.remove(entry.key);
        _notifyCancelled(entry.value.onCancel);
        _reportFailure(error, stack);
        _scheduleDrain();
        return;
      }
      if (ready) {
        owner = entry.key;
        break;
      }
    }
    if (owner == null) return;
    final job = _pending.remove(owner)!;
    _active = true;
    _activeOwner = owner;
    _activeOnCancel = job.onCancel;
    _buildCount++;
    if (_initialWorkCount > _maximumInitialWorkAtStart) _maximumInitialWorkAtStart = _initialWorkCount;
    Future<void> future;
    try {
      future = job.run();
    } catch (error, stack) {
      _reportFailure(error, stack);
      _finish();
      return;
    }
    // Only the running future reaches the asynchronous wait. The queued job
    // record and its run callback are no longer retained by this queue.
    unawaited(_waitForCompletion(future));
  }

  Future<void> _waitForCompletion(Future<void> future) async {
    try {
      await future;
    } catch (error, stack) {
      _reportFailure(error, stack);
    } finally {
      _finish();
    }
  }

  void _finish() {
    _activeOwner = null;
    _activeOnCancel = null;
    _active = false;
    _scheduleDrain();
  }

  void _notifyCancelled(VoidCallback callback) {
    try {
      callback();
    } catch (error, stack) {
      _reportFailure(error, stack);
    }
  }

  void _reportFailure(Object error, StackTrace stack) {
    try {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Contour',
          context: ErrorDescription('while coordinating native glyph verification'),
        ),
      );
    } catch (_) {
      // An error-reporting callback must not strand the serial proof slot.
    }
  }
}
