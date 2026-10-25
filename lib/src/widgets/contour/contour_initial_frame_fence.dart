import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Delays optional contour work until initial foreground geometry is presented.
@internal
class ContourInitialFrameFence {
  new _() : _submitFreshFrame = _submitMainFrame, _timeout = const Duration(seconds: 1) {
    SchedulerBinding.instance.addTimingsCallback(_reportTimings);
  }

  /// Creates an isolated fence with controlled frame submissions for tests.
  @visibleForTesting
  new test({required this._submitFreshFrame, this._timeout = const Duration(seconds: 1)})
    : assert(_timeout > Duration.zero, 'The timing fallback timeout must be positive.');

  /// The initial-presentation fence shared by contour renderers in this isolate.
  static final ContourInitialFrameFence shared = ContourInitialFrameFence._();

  final Future<int> Function() _submitFreshFrame;
  final Duration _timeout;
  Completer<bool>? _completion;
  Timer? _fallbackTimer;
  var _generation = 0;
  var _epoch = 0;
  var _waitingCount = 0;
  var _foregroundCount = 0;
  var _completedEpoch = -1;
  var _targetEpoch = -1;
  var _targetFrame = -1;
  var _lastRasterFrame = -1;
  var _fenceCount = 0;
  var _fallbackCount = 0;
  var _hasTimings = false;
  var _fallbackExpired = false;
  var _scheduled = false;
  var _submitting = false;
  var _opening = false;
  String? _reason;

  /// Whether the current geometry epoch has passed its presentation fence.
  bool get ready => _foregroundCount == 0 && _completedEpoch == _epoch;

  /// The current generation of foreground geometry.
  int get epoch => _epoch;

  /// The most recently submitted target frame, or `-1` before submission.
  int get targetFrame => _targetFrame;

  /// The number of fresh-frame submissions requested by this fence.
  int get fenceCount => _fenceCount;

  /// The number of epochs opened without supported raster timing evidence.
  int get fallbackCount => _fallbackCount;

  /// The number of callers still waiting for presentation or cancellation.
  int get waitingCount => _waitingCount;

  /// Why the current epoch opened, or `null` while it remains unfenced.
  String? get reason => _reason;

  /// Requires a fresh presentation fence for newly attached or changed content.
  void invalidateEpoch() {
    _epoch++;
    _targetEpoch = -1;
    _targetFrame = -1;
    _reason = null;
    _fallbackExpired = false;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    if (_completion?.isCompleted ?? false) _completion = null;
    _scheduleFence();
  }

  /// Holds optional work while foreground geometry is being generated.
  void beginForeground() {
    _foregroundCount++;
    invalidateEpoch();
  }

  /// Releases one foreground hold after its geometry has been installed.
  void endForeground() {
    assert(_foregroundCount > 0, 'Every foreground finish must match a start.');
    _foregroundCount--;
    _scheduleFence();
  }

  /// Waits for the current geometry to be presented before optional work starts.
  ///
  /// A completed [cancelled] future returns `false` for this caller immediately.
  /// Other callers keep waiting when one caller cancels. Cancelling the final
  /// waiter retires the pending fence; a successful epoch remains reusable.
  Future<bool> wait({Future<void>? cancelled}) {
    _waitingCount++;
    final Future<bool> future;
    if (ready) {
      future = Future<bool>.value(true);
    } else {
      future = (_completion ??= Completer<bool>()).future;
      _scheduleFence();
    }
    // The race retains no renderer or owner callback; cancellation belongs only
    // to the caller, while this shared completion remains useful to other work.
    final result = Completer<bool>();
    if (cancelled != null) {
      unawaited(
        cancelled.then(
          (_) {
            if (result.isCompleted) return;
            result.complete(false);
            _finishWaiter();
          },
          onError: (Object error, StackTrace stack) {
            if (result.isCompleted) return;
            result.completeError(error, stack);
            _finishWaiter();
          },
        ),
      );
    }
    unawaited(
      future.then(
        (value) {
          if (result.isCompleted) return;
          result.complete(value);
          _finishWaiter();
        },
        onError: (Object error, StackTrace stack) {
          if (result.isCompleted) return;
          result.completeError(error, stack);
          _finishWaiter();
        },
      ),
    );
    return result.future;
  }

  void _finishWaiter() {
    _waitingCount--;
    if (_waitingCount > 0 || ready) return;
    // No optional consumer remains. Retire its timer and submission generation
    // so a later consumer starts a fresh fence and obsolete callbacks stay inert.
    final completion = _completion;
    _completion = null;
    _generation++;
    _targetEpoch = -1;
    _targetFrame = -1;
    _fallbackExpired = false;
    _scheduled = false;
    _submitting = false;
    _opening = false;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    if (completion != null && !completion.isCompleted) completion.complete(false);
  }

  /// Records a frame whose raster phase has finished on a supported backend.
  void reportRasterFinished(int frameNumber) {
    if (frameNumber < 0) return;
    _hasTimings = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    if (frameNumber > _lastRasterFrame) _lastRasterFrame = frameNumber;
    if (!ready && _targetEpoch == _epoch && _targetFrame <= _lastRasterFrame) _scheduleOpen();
  }

  static Future<int> _submitMainFrame() async {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.idle) await scheduler.endOfFrame;
    // A post-frame callback can queue foreground work in its own microtask.
    // Submit only after those callbacks and their first microtasks have run.
    await Future<void>.value();
    scheduler.scheduleFrame();
    await scheduler.endOfFrame;
    await Future<void>.value();
    return kIsWeb ? -1 : ui.PlatformDispatcher.instance.frameData.frameNumber;
  }

  void _reportTimings(List<ui.FrameTiming> timings) {
    if (timings.isEmpty) return;
    final completion = _completion;
    if (completion == null || completion.isCompleted) {
      // Remember that the backend supports timings without processing every
      // raster report while no optional work is waiting for presentation.
      final frameNumber = timings.last.frameNumber;
      if (frameNumber >= 0) {
        _hasTimings = true;
        if (frameNumber > _lastRasterFrame) _lastRasterFrame = frameNumber;
      }
      return;
    }
    for (final timing in timings) {
      reportRasterFinished(timing.frameNumber);
    }
  }

  void _scheduleFence() {
    if (_scheduled || _submitting || ready || _waitingCount == 0 || _foregroundCount > 0 || _targetEpoch == _epoch) {
      return;
    }
    final completion = _completion;
    if (completion == null || completion.isCompleted) return;
    _scheduled = true;
    final generation = _generation;
    // The second microtask runs after microtasks queued by all post-frame
    // callbacks, including callbacks registered after our own submission wait.
    scheduleMicrotask(() {
      scheduleMicrotask(() {
        if (generation != _generation) return;
        _scheduled = false;
        if (_submitting || ready || _waitingCount == 0 || _foregroundCount > 0 || _targetEpoch == _epoch) return;
        _submitting = true;
        _fenceCount++;
        unawaited(_submit(_epoch, generation));
      });
    });
  }

  Future<void> _submit(int submittedEpoch, int generation) async {
    try {
      final frameNumber = await _submitFreshFrame();
      // The submission may finish before a later post-frame callback's
      // foreground microtask. Recheck after that work has had a chance to start.
      await Future<void>.value();
      if (generation != _generation || submittedEpoch != _epoch || _foregroundCount > 0 || _waitingCount == 0) return;
      _targetEpoch = submittedEpoch;
      _targetFrame = frameNumber;
      if (frameNumber < 0 || _lastRasterFrame >= frameNumber) {
        _scheduleOpen();
      } else if (!_hasTimings) {
        // Some backends never report frame timings. Optional work must remain
        // usable there, but a backend with known timing support must never open
        // a still-pending raster fence merely because wall time has elapsed.
        _fallbackTimer = Timer(_timeout, () {
          if (_hasTimings || generation != _generation || submittedEpoch != _epoch) return;
          _fallbackExpired = true;
          _scheduleOpen();
        });
      }
    } on Object catch (error, stack) {
      if (generation != _generation) return;
      final completion = _completion;
      if (completion != null && !completion.isCompleted) completion.completeError(error, stack);
    } finally {
      if (generation == _generation) {
        _submitting = false;
        _scheduleFence();
      }
    }
  }

  void _scheduleOpen() {
    if (_opening || _waitingCount == 0) return;
    _opening = true;
    final generation = _generation;
    scheduleMicrotask(() {
      scheduleMicrotask(() {
        if (generation != _generation) return;
        _opening = false;
        if (ready || _foregroundCount > 0 || _targetEpoch != _epoch) {
          _scheduleFence();
          return;
        }
        final String reason;
        if (_targetFrame < 0) {
          reason = 'unsupportedFrameId';
        } else if (_lastRasterFrame >= _targetFrame) {
          reason = 'raster';
        } else if (_fallbackExpired && !_hasTimings) {
          reason = 'timingsUnavailable';
        } else {
          return;
        }
        _completedEpoch = _epoch;
        _reason = reason;
        if (reason != 'raster') _fallbackCount++;
        _fallbackTimer?.cancel();
        _fallbackTimer = null;
        final completion = _completion;
        if (completion != null && !completion.isCompleted) completion.complete(true);
      });
    });
  }
}
