part of 'contour.dart';

class _ContourAtlasQueue {
  static const int _maximumQueuedJobs = 64;
  static const int _maximumTransientPixels = 8 * 1024 * 1024;
  static const int _maximumConcurrentJobs = 2;
  static final Map<Object, int> _current = Map.identity();
  static final List<
    ({
      Object owner,
      int token,
      int pixels,
      bool Function() isCurrent,
      Future<ui.Image> Function() build,
      Completer<ui.Image?> result,
    })
  >
  _queue = [];
  static int _nextToken = 0;
  static int _active = 0;
  static int _transientPixels = 0;
  static bool _scheduled = false;
  static Completer<void>? _dispatchCancelled;

  static int get queuedJobs => _queue.length;
  static int get activeJobs => _active;
  static int get transientPixels => _transientPixels;

  static Future<ui.Image?> run({
    required Object owner,
    required int transientPixels,
    required bool Function() isCurrent,
    required Future<ui.Image> Function() build,
  }) {
    cancel(owner);
    _discardObsolete();
    if (_queue.length >= _maximumQueuedJobs || transientPixels > _maximumTransientPixels || transientPixels < 1) {
      return Future<ui.Image?>.value();
    }
    final token = ++_nextToken;
    final result = Completer<ui.Image?>();
    _current[owner] = token;
    _queue.add((
      owner: owner,
      token: token,
      pixels: transientPixels,
      isCurrent: isCurrent,
      build: build,
      result: result,
    ));
    _requestDispatch();
    return result.future;
  }

  static int cancel(Object owner) {
    var removed = 0;
    for (var index = _queue.length - 1; index >= 0; index--) {
      final job = _queue[index];
      if (!identical(job.owner, owner)) continue;
      _queue.removeAt(index);
      if (_current[owner] == job.token) _current.remove(owner);
      job.result.complete(null);
      removed++;
    }
    _cancelEmptyDispatch();
    return removed;
  }

  static void _requestDispatch() {
    if (_scheduled || _queue.isEmpty || _active >= _maximumConcurrentJobs) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(_dispatchAfterFrame());
      });
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  static Future<void> _dispatchAfterFrame() async {
    var cancelled = false;
    try {
      _discardObsolete();
      final fence = ContourInitialFrameFence.shared;
      while (_queue.isNotEmpty && !fence.ready) {
        final cancellation = _dispatchCancelled ??= Completer<void>();
        if (!await fence.wait(cancelled: cancellation.future)) {
          cancelled = true;
          break;
        }
        // Another foreground epoch may have started before this continuation.
        // Keep all jobs queued until the current epoch has been presented.
        _discardObsolete();
      }
    } finally {
      _dispatchCancelled = null;
      _scheduled = false;
    }
    if (cancelled) {
      _requestDispatch();
      return;
    }
    _dispatchOne();
  }

  static void _cancelEmptyDispatch() {
    if (_queue.isNotEmpty) return;
    final cancellation = _dispatchCancelled;
    if (cancellation != null && !cancellation.isCompleted) cancellation.complete();
  }

  static void _discardObsolete() {
    for (var index = _queue.length - 1; index >= 0; index--) {
      final job = _queue[index];
      var retained = false;
      try {
        retained = _current[job.owner] == job.token && job.isCurrent();
      } catch (error, stack) {
        job.result.completeError(error, stack);
      }
      if (retained) continue;
      _queue.removeAt(index);
      if (_current[job.owner] == job.token) _current.remove(job.owner);
      if (!job.result.isCompleted) job.result.complete(null);
    }
    _cancelEmptyDispatch();
  }

  static void _dispatchOne() {
    // Revisions and resource leases may change during this frame's build.
    // Check them only after that work before admitting another GPU allocation.
    _discardObsolete();
    if (_queue.isEmpty || _active >= _maximumConcurrentJobs) return;
    final job = _queue.first;
    if (_transientPixels + job.pixels > _maximumTransientPixels) return;
    _queue.removeAt(0);
    _active++;
    _transientPixels += job.pixels;
    unawaited(_generate(job));
    // A new frame is required even when a synchronous factory completes early.
    _requestDispatch();
  }

  static Future<void> _generate(
    ({
      Object owner,
      int token,
      int pixels,
      bool Function() isCurrent,
      Future<ui.Image> Function() build,
      Completer<ui.Image?> result,
    })
    job,
  ) async {
    ui.Image? image;
    try {
      image = await job.build();
      if (_current[job.owner] == job.token && job.isCurrent()) {
        job.result.complete(image);
        image = null;
      } else {
        job.result.complete(null);
      }
    } catch (error, stack) {
      if (_current[job.owner] == job.token) {
        job.result.completeError(error, stack);
      } else {
        job.result.complete(null);
      }
    } finally {
      if (_current[job.owner] == job.token) _current.remove(job.owner);
      image?.dispose();
      _active--;
      _transientPixels -= job.pixels;
      _requestDispatch();
    }
  }
}
