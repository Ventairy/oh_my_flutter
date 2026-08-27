import 'dart:async';

import 'package:oh_my_flutter/src/exceptions/debouncer_canceled_exception.dart';

/// Delays a value-producing callback until calls have stopped for [delay].
///
/// Calls made while an invocation is pending share one future. Each call
/// restarts the delay and replaces the pending callback, so every awaiter
/// receives the latest callback's value or error.
///
/// By default, scheduling a new callback cancels results from callbacks that
/// already started. Their underlying work continues, but its value or error is
/// discarded.
///
/// ```dart
/// final myDebouncer = Debouncer<List<String>>(
///   delay: const Duration(milliseconds: 300),
/// );
///
/// final results = await myDebouncer(() => searchAddresses(query));
/// ```
///
/// Dispose the debouncer with the lifecycle that owns it. See the
/// [Debouncer guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/debouncer.md)
/// for cancellation and lifecycle usage.
final class Debouncer<T> {
  /// Creates a debouncer that waits for [delay] after the latest call.
  Debouncer({required this.delay, this.switchLatest = true})
    : assert(!delay.isNegative, 'The delay must not be negative.');

  /// Time without another call required before the latest callback starts.
  final Duration delay;

  /// Whether a new call cancels results from callbacks already running.
  ///
  /// Cancellation does not stop the callback's underlying work. Its eventual
  /// value or error is consumed and discarded instead.
  final bool switchLatest;

  Timer? _timer;
  FutureOr<T> Function()? _callback;
  Completer<T>? _completer;
  final Set<Completer<T>> _runningCompleters = <Completer<T>>{};
  bool _disposed = false;

  /// Schedules [callback] and returns the pending burst's shared result.
  ///
  /// Calling this again before [delay] passes replaces the callback and
  /// restarts the timer. All callers waiting on that burst receive the value
  /// or error from the latest callback.
  ///
  /// With [switchLatest] enabled, calling this while an earlier callback is
  /// running cancels the earlier result with [DebouncerCanceledException].
  /// Calling this after [dispose] throws a [StateError].
  Future<T> call(FutureOr<T> Function() callback) {
    if (_disposed) {
      throw StateError('Cannot schedule work with a disposed Debouncer.');
    }

    if (switchLatest) _cancelRunningResults();

    final completer = _completer ?? Completer<T>();
    _timer?.cancel();
    _callback = callback;
    _completer = completer;
    _timer = Timer(delay, _invokePendingCallback);
    return completer.future;
  }

  /// Cancels pending and running results.
  ///
  /// Awaiters receive a [DebouncerCanceledException]. Work that has already
  /// started continues, but its eventual value or error is discarded. The
  /// debouncer remains reusable after cancellation.
  void cancel() {
    _cancelPendingCallback();
    _cancelRunningResults();
  }

  /// Cancels active results and permanently releases this debouncer.
  ///
  /// Awaiters of pending or running results receive a
  /// [DebouncerCanceledException].
  /// Calling this more than once has no additional effect.
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _cancelPendingCallback();
    _cancelRunningResults();
  }

  void _invokePendingCallback() {
    final callback = _callback;
    final completer = _completer;
    _timer = null;
    _callback = null;
    _completer = null;

    if (callback == null || completer == null) return;

    _runningCompleters.add(completer);
    unawaited(
      Future<T>.sync(callback).then<void>(
        (value) => _completeRunningValue(completer: completer, value: value),
        onError: (Object error, StackTrace stackTrace) {
          _completeRunningError(completer: completer, error: error, stackTrace: stackTrace);
        },
      ),
    );
  }

  void _cancelPendingCallback() {
    final completer = _completer;
    _timer?.cancel();
    _timer = null;
    _callback = null;
    _completer = null;

    if (completer == null) return;

    completer.completeError(const DebouncerCanceledException(), StackTrace.current);
  }

  void _cancelRunningResults() {
    if (_runningCompleters.isEmpty) return;

    final canceledCompleters = _runningCompleters.toList(growable: false);
    final stackTrace = StackTrace.current;
    _runningCompleters.clear();
    for (final completer in canceledCompleters) {
      if (!completer.isCompleted) {
        completer.completeError(const DebouncerCanceledException(), stackTrace);
      }
    }
  }

  void _completeRunningValue({required Completer<T> completer, required T value}) {
    _runningCompleters.remove(completer);
    if (completer.isCompleted) return;

    completer.complete(value);
  }

  void _completeRunningError({
    required Completer<T> completer,
    required Object error,
    required StackTrace stackTrace,
  }) {
    _runningCompleters.remove(completer);
    if (completer.isCompleted) return;

    completer.completeError(error, stackTrace);
  }
}
