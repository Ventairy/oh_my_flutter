import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show FrameTiming, ViewFocusEvent;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'interactive_swipe_dismiss_benchmark_interruption_tracker.dart';
import 'interactive_swipe_dismiss_benchmark_motion.dart';
import 'interactive_swipe_dismiss_benchmark_record_buffer.dart';

part '_interactive_swipe_dismiss_benchmark_heavy_child.dart';
part '_interactive_swipe_dismiss_benchmark_probe.dart';
part '_interactive_swipe_dismiss_benchmark_probe_counters.dart';
part '_interactive_swipe_dismiss_benchmark_probe_render_box.dart';
part '_interactive_swipe_dismiss_benchmark_probe_render_object_widget.dart';

const bool _enforceFrameBudget = bool.fromEnvironment(
  'INTERACTIVE_SWIPE_DISMISS_ENFORCE_FRAME_BUDGET',
);
const bool _requireRetainedPaint = bool.fromEnvironment(
  'INTERACTIVE_SWIPE_DISMISS_REQUIRE_RETAINED_PAINT',
);
const int _warmupFrameCount = int.fromEnvironment(
  'INTERACTIVE_SWIPE_DISMISS_WARMUP_FRAMES',
  defaultValue: 180,
);
const int _measuredFrameCount = int.fromEnvironment(
  'INTERACTIVE_SWIPE_DISMISS_MEASURED_FRAMES',
  defaultValue: 600,
);
const String _rendererName = String.fromEnvironment(
  'INTERACTIVE_SWIPE_DISMISS_RENDERER',
  defaultValue: 'unspecified',
);
const String _runId = String.fromEnvironment(
  'INTERACTIVE_SWIPE_DISMISS_RUN_ID',
  defaultValue: 'unspecified',
);

/// Profile-mode benchmark for the Cataqui-style interactive-dismiss path.
class InteractiveSwipeDismissBenchmark extends StatefulWidget {
  /// Creates the benchmark application.
  const InteractiveSwipeDismissBenchmark({super.key});

  @override
  State<InteractiveSwipeDismissBenchmark> createState() {
    return _InteractiveSwipeDismissBenchmarkState();
  }
}

// The configured formatter keeps this intrinsic class declaration on one
// line.
// ignore: lines_longer_than_80_chars
class _InteractiveSwipeDismissBenchmarkState extends State<InteractiveSwipeDismissBenchmark>
    with WidgetsBindingObserver {
  static const String _scenario = 'cataqui_scrolled_header_free_drag';
  static const int _steadyTrialCount = 2;
  static const int _maximumTrialAttempts = 3;
  static const int _heavyRowCount = 80;
  static const int _pointerDevice = 9741;
  static const double _headerHeight = 84;
  static const double _initialScrollOffset = 600;
  static const double _scrollTolerance = 0.01;
  static const double _sensitivity = 0.37;
  static const double _dismissThreshold = 0.25;
  static const Duration _interactionTimeout = Duration(minutes: 2);
  static const Duration _timingsTimeout = Duration(minutes: 2);
  static const Duration _viewMetricsTimeout = Duration(seconds: 30);
  static const Duration _restoreSettleDuration = Duration(milliseconds: 340);

  final GlobalKey _handleKey = GlobalKey();
  final GlobalKey _surfaceKey = GlobalKey();
  final Stopwatch _dispatchStopwatch = Stopwatch();
  final List<String> _failedSteadyPaths = <String>[];
  late final ScrollController _scrollController;
  late final Widget _retainedWorkload;
  // The configured formatter keeps this descriptive field declaration on one
  // line.
  // ignore: lines_longer_than_80_chars
  late final InteractiveSwipeDismissBenchmarkInterruptionTracker _interruptionTracker;
  late final InteractiveSwipeDismissBenchmarkRecordBuffer _recordBuffer;

  Completer<void>? _interactionChanged;
  Completer<void>? _windowCompleted;
  Completer<void>? _windowInteractionChanged;
  List<FrameTiming?> _windowFrames = const <FrameTiming?>[];
  List<int> _windowDispatchDurations = const <int>[];
  int _windowFrameCount = 0;
  int _windowMoveCount = 0;
  int _windowTargetFrames = 0;
  int _windowProbeBuildStart = 0;
  int _windowProbeLayoutStart = 0;
  int _windowProbePaintStart = 0;
  int _windowDismissCallbackStart = 0;
  int _maximumTransientCallbacks = 0;
  int _invalidTrialAttempts = 0;
  int _retriedTrials = 0;
  int _dismissCallbackCount = 0;
  int _nextPointer = 1000;
  int? _scheduledGestureFrame;
  int? _windowStartMicros;
  double _refreshRate = 0;
  double _windowScrollStart = 0;
  double _maximumScrollDrift = 0;
  double _maximumRawPrimary = 0;
  int? _benchmarkViewId;
  int? _activePointer;
  Offset _pointerPosition = Offset.zero;
  InteractiveSwipeDismissBenchmarkMotion? _activeMotion;
  bool _animationsDisabled = false;
  bool _windowIsActive = false;
  bool _preflightPassed = false;
  int _frameBudgetMicros = 0;
  ({
    double devicePixelRatio,
    Size logicalSize,
    Size physicalSize,
    double refreshRate,
  })?
  _environmentViewMetrics;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _initialScrollOffset,
    );
    _retainedWorkload = KeyedSubtree(
      key: _surfaceKey,
      child: _InteractiveSwipeDismissBenchmarkProbe(
        child: _InteractiveSwipeDismissBenchmarkHeavyChild(
          handleKey: _handleKey,
          scrollController: _scrollController,
        ),
      ),
    );
    _interruptionTracker = InteractiveSwipeDismissBenchmarkInterruptionTracker(
      WidgetsBinding.instance.lifecycleState,
    );
    _recordBuffer = InteractiveSwipeDismissBenchmarkRecordBuffer(
      (message) => debugPrint(message, wrapWidth: 4000),
    );
    WidgetsBinding.instance
      ..addObserver(this)
      ..addTimingsCallback(_handleTimings)
      ..addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = View.of(context);
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    _interruptionTracker.viewId = view.viewId;
    _benchmarkViewId = view.viewId;
    _refreshRate = view.display.refreshRate;
    if (_refreshRate.isFinite && _refreshRate > 0) {
      _frameBudgetMicros = _frameBudgetFor(_refreshRate);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_interruptionTracker.updateLifecycle(state)) {
      _signalInteractionChanged();
    }
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (_interruptionTracker.updateViewFocus(event)) {
      _signalInteractionChanged();
    }
  }

  @override
  void dispose() {
    final scheduledGestureFrame = _scheduledGestureFrame;
    if (scheduledGestureFrame != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(
        scheduledGestureFrame,
      );
    }
    _cancelActivePointer();
    WidgetsBinding.instance
      ..removeObserver(this)
      ..removeTimingsCallback(_handleTimings);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    var passed = false;
    try {
      await _captureValidViewMetrics();
      await _waitForWorkloadReady();
      _validateEnvironment();
      await _runInteractionPreflight();
      _printEnvironment();
      for (var trial = 1; trial <= _steadyTrialCount; trial += 1) {
        final measurement = await _collectSteadyTrial(trial);
        _printSteadyResult(trial: trial, measurement: measurement);
      }
      passed = _failedSteadyPaths.isEmpty;
      _print(<String, Object>{
        'path': 'acceptance',
        'run_id': _runId,
        'passed': passed,
        'enforced': _enforceFrameBudget,
        'failed_steady_paths': _failedSteadyPaths,
        'steady_trials': _steadyTrialCount,
        'steady_frames_per_trial': _measuredFrameCount,
        'maximum_trial_attempts': _maximumTrialAttempts,
        'invalid_trial_attempts': _invalidTrialAttempts,
        'retried_trials': _retriedTrials,
      });
    } on Object catch (error, stackTrace) {
      _print(<String, Object>{
        'path': 'error',
        'run_id': _runId,
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
      });
    } finally {
      WidgetsBinding.instance.removeTimingsCallback(_handleTimings);
      _recordBuffer.flush();
      await debugPrintDone;
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await SystemNavigator.pop();
        exit(_enforceFrameBudget && !passed ? 1 : 0);
      });
    }
  }

  void _validateEnvironment() {
    if (!kProfileMode) {
      throw StateError(
        'The InteractiveSwipeDismiss benchmark must run in profile mode.',
      );
    }
    final normalizedRenderer = _rendererName.trim().toLowerCase();
    if (normalizedRenderer.isEmpty || normalizedRenderer == 'unspecified') {
      throw StateError(
        'Set INTERACTIVE_SWIPE_DISMISS_RENDERER after verifying device logs.',
      );
    }
    if (_runId.trim().isEmpty || _runId.trim().toLowerCase() == 'unspecified') {
      throw StateError('Set a fresh INTERACTIVE_SWIPE_DISMISS_RUN_ID.');
    }
    if (!_refreshRate.isFinite || _refreshRate <= 0) {
      throw StateError('The display reported an invalid refresh rate.');
    }
    if (_environmentViewMetrics == null) {
      throw StateError('The benchmark did not capture valid view metrics.');
    }
    if (_animationsDisabled) {
      throw StateError(
        'InteractiveSwipeDismiss benchmarking requires animations enabled.',
      );
    }
    if (_warmupFrameCount < 2 || _measuredFrameCount < 2) {
      throw StateError(
        'Warmup and measured frame counts must be at least two.',
      );
    }
    final viewMetrics = _environmentViewMetrics!;
    final maximumTravel = InteractiveSwipeDismissBenchmarkMotion(
      origin: Offset.zero,
      viewportSize: viewMetrics.logicalSize,
    ).maximumPrimaryTravel;
    final dismissDistance = viewMetrics.logicalSize.height * _dismissThreshold;
    if (maximumTravel <= 24 || maximumTravel >= dismissDistance) {
      throw StateError(
        'The benchmark viewport cannot contain its below-threshold path.',
      );
    }
  }

  void _printEnvironment() {
    final viewMetrics = _environmentViewMetrics!;
    _print(<String, Object>{
      'path': 'environment',
      'run_id': _runId,
      'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
      'platform': defaultTargetPlatform.name,
      'operating_system': Platform.operatingSystemVersion,
      'renderer': _rendererName,
      'renderer_source': 'manually verified startup or device logs',
      'scenario': _scenario,
      'direction': 'down',
      'free_drag': true,
      'sensitivity': _sensitivity,
      'dismiss_threshold': _dismissThreshold,
      'initial_scroll_offset_px': _initialScrollOffset,
      'heavy_row_count': _heavyRowCount,
      'gesture_driver': 'synthetic_touch_one_move_per_vsync',
      'refresh_rate_hz': _refreshRate,
      'frame_budget_us': _frameBudgetMicros,
      'logical_size': <String, double>{
        'width': viewMetrics.logicalSize.width,
        'height': viewMetrics.logicalSize.height,
      },
      'physical_size': <String, double>{
        'width': viewMetrics.physicalSize.width,
        'height': viewMetrics.physicalSize.height,
      },
      'device_pixel_ratio': viewMetrics.devicePixelRatio,
      'animations_disabled': _animationsDisabled,
      'preflight_passed': _preflightPassed,
      'require_retained_paint': _requireRetainedPaint,
      'warmup_frames_per_trial': _warmupFrameCount,
      'steady_trials': _steadyTrialCount,
      'steady_frames_per_trial': _measuredFrameCount,
      'maximum_trial_attempts': _maximumTrialAttempts,
    });
  }

  Future<void> _captureValidViewMetrics() async {
    await _captureValidViewMetricsWithoutTimeout().timeout(
      _viewMetricsTimeout,
      onTimeout: () => throw TimeoutException(
        'The benchmark view did not report finite, nonzero metrics.',
        _viewMetricsTimeout,
      ),
    );
  }

  Future<void> _captureValidViewMetricsWithoutTimeout() async {
    final view = View.of(context);
    while (mounted) {
      final physicalSize = view.physicalSize;
      final devicePixelRatio = view.devicePixelRatio;
      final logicalSize = physicalSize / devicePixelRatio;
      final refreshRate = view.display.refreshRate;
      if (_sizeIsFiniteAndPositive(logicalSize) &&
          _sizeIsFiniteAndPositive(physicalSize) &&
          _isFiniteAndPositive(devicePixelRatio) &&
          _isFiniteAndPositive(refreshRate)) {
        _environmentViewMetrics = (
          devicePixelRatio: devicePixelRatio,
          logicalSize: logicalSize,
          physicalSize: physicalSize,
          refreshRate: refreshRate,
        );
        _refreshRate = refreshRate;
        _frameBudgetMicros = _frameBudgetFor(refreshRate);
        _interruptionTracker.viewId = view.viewId;
        _benchmarkViewId = view.viewId;
        return;
      }
      await _waitUntilInteractive();
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    throw StateError('The benchmark was disposed before startup.');
  }

  Future<void> _waitForWorkloadReady() async {
    await _waitForWorkloadReadyWithoutTimeout().timeout(
      _viewMetricsTimeout,
      onTimeout: () => throw TimeoutException(
        'The benchmark workload did not become ready.',
        _viewMetricsTimeout,
      ),
    );
  }

  Future<void> _waitForWorkloadReadyWithoutTimeout() async {
    while (mounted) {
      final handle = _handleKey.currentContext?.findRenderObject();
      final surface = _surfaceKey.currentContext?.findRenderObject();
      final scrollReady =
          _scrollController.hasClients &&
          _scrollController.position.hasContentDimensions &&
          _scrollController.position.maxScrollExtent > _initialScrollOffset;
      final geometryReady =
          handle is RenderBox &&
          handle.attached &&
          handle.hasSize &&
          surface is RenderBox &&
          surface.attached &&
          surface.hasSize;
      if (scrollReady && geometryReady) {
        final scrollOffset = _scrollController.offset;
        final scrollOffsetError = (scrollOffset - _initialScrollOffset).abs();
        if (scrollOffsetError > _scrollTolerance) {
          _scrollController.jumpTo(_initialScrollOffset);
          await SchedulerBinding.instance.endOfFrame;
          continue;
        }
        await _flushReportedTimings();
        return;
      }
      await _waitUntilInteractive();
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    throw StateError(
      'The benchmark was disposed before its workload was ready.',
    );
  }

  Future<void> _runInteractionPreflight() async {
    final initialSurfaceOrigin = _surfaceOrigin;
    final initialScrollOffset = _scrollController.offset;
    final dismissCallbacks = _dismissCallbackCount;
    _beginGesture();
    final motion = _activeMotion!;
    final target = motion.positionForStep(0);
    final delta = target - _pointerPosition;
    _dispatchPointerMove(target: target, delta: delta);
    await SchedulerBinding.instance.endOfFrame;

    final actualTranslation = _surfaceOrigin - initialSurfaceOrigin;
    final expectedTranslation = delta * _sensitivity;
    final translationError = (actualTranslation - expectedTranslation).distance;
    final scrollDrift = (_scrollController.offset - initialScrollOffset).abs();
    final callbackDelta = _dismissCallbackCount - dismissCallbacks;
    await _cancelGestureAndSettle();
    final translationFailed = translationError > 0.75;
    final scrollFailed = scrollDrift > _scrollTolerance;
    final callbackFailed = callbackDelta != 0;
    final preflightFailed = translationFailed || scrollFailed || callbackFailed;
    if (preflightFailed) {
      throw StateError(
        'Interactive preflight failed: translation_error=$translationError, '
        'scroll_drift=$scrollDrift, dismiss_callbacks=$callbackDelta.',
      );
    }
    _preflightPassed = true;
  }

  Future<
    ({
      int attempt,
      int dismissCallbacks,
      List<int> dispatchDurations,
      List<FrameTiming> frames,
      int maximumTransientCallbacks,
      double maximumRawPrimary,
      double maximumScrollDrift,
      int pointerMoves,
      int probeBuilds,
      int probeLayouts,
      int probePaints,
      double scrollEnd,
      double scrollStart,
    })
  >
  _collectSteadyTrial(int trial) async {
    for (var attempt = 1; attempt <= _maximumTrialAttempts; attempt += 1) {
      await _warmTrial();
      final measurement = await _collectFrameWindow(
        targetFrames: _measuredFrameCount,
        measured: true,
      );
      if (!measurement.interrupted) {
        return (
          attempt: attempt,
          dismissCallbacks: measurement.dismissCallbacks,
          dispatchDurations: measurement.dispatchDurations,
          frames: measurement.frames,
          maximumTransientCallbacks: measurement.maximumTransientCallbacks,
          maximumRawPrimary: measurement.maximumRawPrimary,
          maximumScrollDrift: measurement.maximumScrollDrift,
          pointerMoves: measurement.pointerMoves,
          probeBuilds: measurement.probeBuilds,
          probeLayouts: measurement.probeLayouts,
          probePaints: measurement.probePaints,
          scrollEnd: measurement.scrollEnd,
          scrollStart: measurement.scrollStart,
        );
      }
      _reportInvalidTrialAttempt(
        trial: trial,
        attempt: attempt,
        reasons: measurement.invalidReasons,
        collectedFrames: measurement.frames.length,
        pointerMoves: measurement.pointerMoves,
      );
    }
    throw StateError(
      'InteractiveSwipeDismiss steady trial $trial was interrupted '
      '$_maximumTrialAttempts consecutive times.',
    );
  }

  Future<void> _warmTrial() async {
    while (true) {
      final warmup = await _collectFrameWindow(
        targetFrames: _warmupFrameCount,
        measured: false,
      );
      if (!warmup.interrupted) return;
    }
  }

  Future<
    ({
      int dismissCallbacks,
      List<int> dispatchDurations,
      List<FrameTiming> frames,
      List<String> invalidReasons,
      bool interrupted,
      int maximumTransientCallbacks,
      double maximumRawPrimary,
      double maximumScrollDrift,
      int pointerMoves,
      int probeBuilds,
      int probeLayouts,
      int probePaints,
      double scrollEnd,
      double scrollStart,
    })
  >
  _collectFrameWindow({
    required int targetFrames,
    required bool measured,
  }) async {
    await _waitUntilInteractive();
    await _restoreInitialScrollOffset();
    await _flushReportedTimings();
    if (_windowIsActive || _activePointer != null) {
      throw StateError('A swipe timing window was already active.');
    }

    final completed = Completer<void>();
    _windowFrames = List<FrameTiming?>.filled(targetFrames, null);
    _windowDispatchDurations = List<int>.filled(targetFrames, 0);
    _windowFrameCount = 0;
    _windowMoveCount = 0;
    _windowTargetFrames = targetFrames;
    final probeStart = _InteractiveSwipeDismissBenchmarkProbeCounters.snapshot;
    _windowProbeBuildStart = probeStart.builds;
    _windowProbeLayoutStart = probeStart.layouts;
    _windowProbePaintStart = probeStart.paints;
    _windowDismissCallbackStart = _dismissCallbackCount;
    _windowScrollStart = _scrollController.offset;
    _maximumScrollDrift = 0;
    _maximumRawPrimary = 0;
    _maximumTransientCallbacks = 0;
    _windowStartMicros = null;
    _windowCompleted = completed;
    _windowInteractionChanged = Completer<void>();
    _windowIsActive = true;
    _interruptionTracker.startWindow(collectFrames: measured);
    _beginGesture();
    _scheduleGestureFrame();

    var interrupted = false;
    var invalidReasons = const <String>[];
    try {
      final completedNormally = await Future.any<bool>(<Future<bool>>[
        completed.future.then((_) => true),
        _windowInteractionChanged!.future.then((_) => false),
      ]).timeout(_timingsTimeout);
      invalidReasons = _interruptionTracker.invalidReasons;
      interrupted = !completedNormally || invalidReasons.isNotEmpty;
      if (interrupted && invalidReasons.isEmpty) {
        invalidReasons = const <String>[
          'interaction_changed_during_window',
        ];
      }
    } finally {
      final scheduledGestureFrame = _scheduledGestureFrame;
      if (scheduledGestureFrame != null) {
        SchedulerBinding.instance.cancelFrameCallbackWithId(
          scheduledGestureFrame,
        );
        _scheduledGestureFrame = null;
      }
      _interruptionTracker.endWindow();
      _windowIsActive = false;
      _windowCompleted = null;
      _windowInteractionChanged = null;
    }

    final frames = List<FrameTiming>.generate(
      _windowFrameCount,
      (index) => _windowFrames[index]!,
      growable: false,
    );
    final dispatchDurations = List<int>.of(
      _windowDispatchDurations.take(_windowMoveCount),
      growable: false,
    );
    final probeEnd = _InteractiveSwipeDismissBenchmarkProbeCounters.snapshot;
    final result = (
      dismissCallbacks: _dismissCallbackCount - _windowDismissCallbackStart,
      dispatchDurations: dispatchDurations,
      frames: frames,
      invalidReasons: invalidReasons,
      interrupted: interrupted,
      maximumTransientCallbacks: _maximumTransientCallbacks,
      maximumRawPrimary: _maximumRawPrimary,
      maximumScrollDrift: _maximumScrollDrift,
      pointerMoves: _windowMoveCount,
      probeBuilds: probeEnd.builds - _windowProbeBuildStart,
      probeLayouts: probeEnd.layouts - _windowProbeLayoutStart,
      probePaints: probeEnd.paints - _windowProbePaintStart,
      scrollEnd: _scrollController.offset,
      scrollStart: _windowScrollStart,
    );
    await _cancelGestureAndSettle();
    _windowStartMicros = null;
    _windowTargetFrames = 0;
    return result;
  }

  void _scheduleGestureFrame() {
    _scheduledGestureFrame = SchedulerBinding.instance.scheduleFrameCallback(
      _driveGestureFrame,
    );
  }

  void _driveGestureFrame(Duration timeStamp) {
    _scheduledGestureFrame = null;
    if (!_windowIsActive || _windowMoveCount >= _windowTargetFrames) return;
    _windowStartMicros ??= timeStamp.inMicroseconds;
    final motion = _activeMotion!;
    final target = motion.positionForStep(_windowMoveCount);
    final delta = target - _pointerPosition;

    _dispatchStopwatch
      ..reset()
      ..start();
    _dispatchPointerMove(target: target, delta: delta);
    _dispatchStopwatch.stop();
    final dispatchDuration = _dispatchStopwatch.elapsedMicroseconds;
    _windowDispatchDurations[_windowMoveCount] = dispatchDuration;
    _windowMoveCount += 1;

    final primary = target.dy - motion.origin.dy;
    if (primary > _maximumRawPrimary) _maximumRawPrimary = primary;
    final scrollDrift = (_scrollController.offset - _windowScrollStart).abs();
    if (scrollDrift > _maximumScrollDrift) {
      _maximumScrollDrift = scrollDrift;
    }

    if (_windowMoveCount < _windowTargetFrames) {
      _scheduleGestureFrame();
    }
    _maximumTransientCallbacks = math.max(
      _maximumTransientCallbacks,
      SchedulerBinding.instance.transientCallbackCount,
    );
    _completeWindowIfReady();
  }

  void _handleTimings(List<FrameTiming> timings) {
    if (!_windowIsActive) return;
    final windowStart = _windowStartMicros;
    if (windowStart == null) return;
    for (final timing in timings) {
      final buildStart = timing.timestampInMicroseconds(
        ui.FramePhase.buildStart,
      );
      if (buildStart < windowStart) continue;
      if (_windowFrameCount >= _windowTargetFrames) break;
      _windowFrames[_windowFrameCount++] = timing;
    }
    _completeWindowIfReady();
  }

  void _completeWindowIfReady() {
    final movesAreComplete = _windowMoveCount == _windowTargetFrames;
    final timingsAreComplete = _windowFrameCount == _windowTargetFrames;
    if (!movesAreComplete || !timingsAreComplete) {
      return;
    }
    final completed = _windowCompleted;
    if (completed != null && !completed.isCompleted) completed.complete();
  }

  void _beginGesture() {
    final handle = _handleKey.currentContext?.findRenderObject();
    if (handle is! RenderBox || !handle.attached || !handle.hasSize) {
      throw StateError('The benchmark handle has no usable geometry.');
    }
    final origin = handle.localToGlobal(handle.size.center(Offset.zero));
    final pointer = _nextPointer++;
    final viewId = _benchmarkViewId;
    if (viewId == null) {
      throw StateError('The benchmark view ID is unavailable.');
    }
    _activePointer = pointer;
    _pointerPosition = origin;
    _activeMotion = InteractiveSwipeDismissBenchmarkMotion(
      origin: origin,
      viewportSize: _environmentViewMetrics!.logicalSize,
    );
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        viewId: viewId,
        timeStamp: SchedulerBinding.instance.currentSystemFrameTimeStamp,
        pointer: pointer,
        device: _pointerDevice,
        position: origin,
      ),
    );
  }

  void _dispatchPointerMove({
    required Offset target,
    required Offset delta,
  }) {
    final pointer = _activePointer;
    final viewId = _benchmarkViewId;
    if (pointer == null || viewId == null) return;
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        viewId: viewId,
        timeStamp: SchedulerBinding.instance.currentSystemFrameTimeStamp,
        pointer: pointer,
        device: _pointerDevice,
        position: target,
        delta: delta,
      ),
    );
    _pointerPosition = target;
  }

  Future<void> _cancelGestureAndSettle() async {
    _cancelActivePointer();
    await Future<void>.delayed(_restoreSettleDuration);
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
  }

  void _cancelActivePointer() {
    final pointer = _activePointer;
    if (pointer == null) return;
    final viewId = _benchmarkViewId;
    _activePointer = null;
    _activeMotion = null;
    if (viewId == null) return;
    GestureBinding.instance.handlePointerEvent(
      PointerCancelEvent(
        viewId: viewId,
        timeStamp: SchedulerBinding.instance.currentSystemFrameTimeStamp,
        pointer: pointer,
        device: _pointerDevice,
        position: _pointerPosition,
      ),
    );
  }

  Future<void> _restoreInitialScrollOffset() async {
    final drift = (_scrollController.offset - _initialScrollOffset).abs();
    if (drift <= _scrollTolerance) return;
    _scrollController.jumpTo(_initialScrollOffset);
    await SchedulerBinding.instance.endOfFrame;
  }

  Future<void> _flushReportedTimings() async {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }

  Future<void> _waitUntilInteractive() async {
    while (!_interruptionTracker.isInteractive) {
      final completer = Completer<void>();
      _interactionChanged = completer;
      if (_interruptionTracker.isInteractive) {
        _interactionChanged = null;
        return;
      }
      try {
        await completer.future.timeout(_interactionTimeout);
      } on TimeoutException {
        throw TimeoutException(
          'The benchmark did not regain lifecycle and view focus.',
          _interactionTimeout,
        );
      } finally {
        if (identical(_interactionChanged, completer)) {
          _interactionChanged = null;
        }
      }
    }
  }

  void _signalInteractionChanged() {
    final interactionCompleter = _interactionChanged;
    if (interactionCompleter != null && !interactionCompleter.isCompleted) {
      interactionCompleter.complete();
    }
    final windowCompleter = _windowInteractionChanged;
    if (windowCompleter != null && !windowCompleter.isCompleted) {
      windowCompleter.complete();
    }
  }

  void _reportInvalidTrialAttempt({
    required int trial,
    required int attempt,
    required List<String> reasons,
    required int collectedFrames,
    required int pointerMoves,
  }) {
    final retrying = attempt < _maximumTrialAttempts;
    _invalidTrialAttempts += 1;
    if (attempt == 1 && retrying) _retriedTrials += 1;
    _print(<String, Object>{
      'path': 'steady.trial_$trial.invalid.attempt_$attempt',
      'run_id': _runId,
      'phase': 'steady',
      'trial': trial,
      'attempt': attempt,
      'valid': false,
      'invalid_reasons': reasons,
      'collected_frames': collectedFrames,
      'pointer_moves': pointerMoves,
      'retrying': retrying,
      'maximum_trial_attempts': _maximumTrialAttempts,
    });
  }

  void _printSteadyResult({
    required int trial,
    required ({
      int attempt,
      int dismissCallbacks,
      List<int> dispatchDurations,
      List<FrameTiming> frames,
      int maximumTransientCallbacks,
      double maximumRawPrimary,
      double maximumScrollDrift,
      int pointerMoves,
      int probeBuilds,
      int probeLayouts,
      int probePaints,
      double scrollEnd,
      double scrollStart,
    })
    measurement,
  }) {
    final buildMicros = <int>[];
    final rasterMicros = <int>[];
    final totalSpanMicros = <int>[];
    final vsyncOverheadMicros = <int>[];
    var buildOverBudget = 0;
    var rasterOverBudget = 0;
    var totalSpanOverBudget = 0;
    var anyOverBudget = 0;
    var longestConsecutiveMisses = 0;
    var consecutiveMisses = 0;

    for (final timing in measurement.frames) {
      final build = timing.buildDuration.inMicroseconds;
      final raster = timing.rasterDuration.inMicroseconds;
      final totalSpan = timing.totalSpan.inMicroseconds;
      final vsyncOverhead = timing.vsyncOverhead.inMicroseconds;
      buildMicros.add(build);
      rasterMicros.add(raster);
      totalSpanMicros.add(totalSpan);
      vsyncOverheadMicros.add(vsyncOverhead);
      if (build > _frameBudgetMicros) buildOverBudget += 1;
      if (raster > _frameBudgetMicros) rasterOverBudget += 1;
      if (totalSpan > _frameBudgetMicros) totalSpanOverBudget += 1;
      final buildMissed = build > _frameBudgetMicros;
      final rasterMissed = raster > _frameBudgetMicros;
      final totalSpanMissed = totalSpan > _frameBudgetMicros;
      final missed = buildMissed || rasterMissed || totalSpanMissed;
      if (missed) {
        anyOverBudget += 1;
        consecutiveMisses += 1;
        longestConsecutiveMisses = math.max(
          longestConsecutiveMisses,
          consecutiveMisses,
        );
      } else {
        consecutiveMisses = 0;
      }
    }

    final build = _summarize(buildMicros);
    final raster = _summarize(rasterMicros);
    final buildFitsBudget = build['p99_us']! <= _frameBudgetMicros;
    final rasterFitsBudget = raster['p99_us']! <= _frameBudgetMicros;
    final workFitsBudget = buildFitsBudget && rasterFitsBudget;
    final viewMetrics = _environmentViewMetrics!;
    final dismissDistance = viewMetrics.logicalSize.height * _dismissThreshold;
    final scrollStart = measurement.scrollStart;
    final scrollEnd = measurement.scrollEnd;
    final scrollDisplacement = (scrollEnd - scrollStart).abs();
    final structuralPass =
        measurement.pointerMoves == _measuredFrameCount &&
        measurement.dispatchDurations.length == _measuredFrameCount &&
        measurement.probeBuilds == 0 &&
        measurement.probeLayouts == 0 &&
        (!_requireRetainedPaint || measurement.probePaints == 0) &&
        measurement.maximumScrollDrift <= _scrollTolerance &&
        scrollDisplacement <= _scrollTolerance &&
        measurement.dismissCallbacks == 0 &&
        measurement.maximumTransientCallbacks <= 1 &&
        measurement.maximumRawPrimary > 0 &&
        measurement.maximumRawPrimary < dismissDistance;
    final path = 'steady.trial_$trial';
    if (!workFitsBudget || !structuralPass) _failedSteadyPaths.add(path);

    _print(<String, Object>{
      'path': path,
      'run_id': _runId,
      'scenario': _scenario,
      'phase': 'steady',
      'trial': trial,
      'attempt': measurement.attempt,
      'retried': measurement.attempt > 1,
      'valid': true,
      'gate': true,
      'frames': measurement.frames.length,
      'pointer_moves': measurement.pointerMoves,
      'frame_timings_us': <String, Object>{
        'build': buildMicros,
        'raster': rasterMicros,
        'total_span': totalSpanMicros,
        'vsync_overhead': vsyncOverheadMicros,
      },
      'build': build,
      'raster': raster,
      'total_span': _summarize(totalSpanMicros),
      'vsync_overhead': _summarize(vsyncOverheadMicros),
      'dispatch_durations_us': measurement.dispatchDurations,
      'dispatch': _summarize(measurement.dispatchDurations),
      'probe_builds': measurement.probeBuilds,
      'probe_layouts': measurement.probeLayouts,
      'probe_paints': measurement.probePaints,
      'retained_paint_required': _requireRetainedPaint,
      'scroll_start_px': measurement.scrollStart,
      'scroll_end_px': measurement.scrollEnd,
      'maximum_scroll_drift_px': measurement.maximumScrollDrift,
      'dismiss_callbacks': measurement.dismissCallbacks,
      'maximum_transient_callbacks': measurement.maximumTransientCallbacks,
      'maximum_raw_primary_px': measurement.maximumRawPrimary,
      'dismiss_distance_px': dismissDistance,
      'build_over_budget': buildOverBudget,
      'raster_over_budget': rasterOverBudget,
      'total_span_over_budget': totalSpanOverBudget,
      'any_over_budget': anyOverBudget,
      'longest_consecutive_misses': longestConsecutiveMisses,
      'work_p99_within_budget': workFitsBudget,
      'structural_invariants_passed': structuralPass,
      'frame_budget_us': _frameBudgetMicros,
    });
  }

  Map<String, num> _summarize(List<int> values) {
    if (values.isEmpty) {
      throw StateError('Cannot summarize an empty benchmark distribution.');
    }
    final sortedValues = List<int>.of(values, growable: false)..sort();
    final total = sortedValues.fold<int>(0, (sum, value) => sum + value);
    return <String, num>{
      'minimum_us': sortedValues.first,
      'p50_us': _percentile(sortedValues, 0.50),
      'p90_us': _percentile(sortedValues, 0.90),
      'p99_us': _percentile(sortedValues, 0.99),
      'max_us': sortedValues.last,
      'mean_us': total / sortedValues.length,
    };
  }

  int _percentile(List<int> sortedValues, double percentile) {
    final index = ((sortedValues.length * percentile).ceil() - 1).clamp(
      0,
      sortedValues.length - 1,
    );
    return sortedValues[index];
  }

  bool _sizeIsFiniteAndPositive(Size size) {
    final widthIsValid = _isFiniteAndPositive(size.width);
    final heightIsValid = _isFiniteAndPositive(size.height);
    return widthIsValid && heightIsValid;
  }

  int _frameBudgetFor(double refreshRate) {
    return (Duration.microsecondsPerSecond / refreshRate).floor();
  }

  bool _isFiniteAndPositive(double value) => value.isFinite && value > 0;

  Offset get _surfaceOrigin {
    final surface = _surfaceKey.currentContext?.findRenderObject();
    if (surface is! RenderBox || !surface.attached || !surface.hasSize) {
      throw StateError('The benchmark surface has no usable geometry.');
    }
    return surface.localToGlobal(Offset.zero);
  }

  FutureOr<bool> _onDismiss() {
    _dismissCallbackCount += 1;
    return false;
  }

  void _print(Map<String, Object> result) {
    _recordBuffer.add(result);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xB8000000),
        body: SafeArea(
          minimum: const EdgeInsets.all(12),
          child: InteractiveSwipeDismiss(
            dragConfig: const InteractiveSwipeDismissDragConfig(
              freeDrag: true,
              sensitivity: _sensitivity,
              dismissThreshold: _dismissThreshold,
            ),
            onDismiss: _onDismiss,
            child: _retainedWorkload,
          ),
        ),
      ),
    );
  }
}
