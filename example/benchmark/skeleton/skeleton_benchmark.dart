import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show FrameTiming, ViewFocusEvent;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'skeleton_benchmark_interruption_tracker.dart';
import 'skeleton_benchmark_record_buffer.dart';

part '_benchmark_card.dart';
part '_paint_probe_painter.dart';

const bool _enforceFrameBudget = bool.fromEnvironment(
  'SKELETON_ENFORCE_FRAME_BUDGET',
);
const int _warmupFrameCount = int.fromEnvironment(
  'SKELETON_WARMUP_FRAMES',
  defaultValue: 180,
);
const int _measuredFrameCount = int.fromEnvironment(
  'SKELETON_MEASURED_FRAMES',
  defaultValue: 600,
);
const int _cardCount = int.fromEnvironment(
  'SKELETON_CARD_COUNT',
  defaultValue: 16,
);
const String _effectName = String.fromEnvironment(
  'SKELETON_EFFECT',
  defaultValue: 'shimmer',
);
const String _topologyName = String.fromEnvironment(
  'SKELETON_TOPOLOGY',
  defaultValue: 'single',
);
const String _rendererName = String.fromEnvironment(
  'SKELETON_RENDERER',
  defaultValue: 'unspecified',
);
const String _runId = String.fromEnvironment(
  'SKELETON_RUN_ID',
  defaultValue: 'unspecified',
);

/// A profile-mode stress benchmark for animated [Skeleton] painting.
class SkeletonBenchmark extends StatefulWidget {
  /// Creates the benchmark application.
  const SkeletonBenchmark({super.key});

  @override
  State<SkeletonBenchmark> createState() => _SkeletonState();
}

// The formatter keeps this declaration on one line at its 120-column width.
// ignore: lines_longer_than_80_chars
class _SkeletonState extends State<SkeletonBenchmark> with WidgetsBindingObserver {
  static const int _steadyTrialCount = 2;
  static const int _maximumTrialAttempts = 3;
  static const Duration _interactionTimeout = Duration(minutes: 2);
  static const Duration _timingsTimeout = Duration(minutes: 2);
  static const Duration _viewMetricsTimeout = Duration(seconds: 30);

  final List<FrameTiming> _windowFrames = <FrameTiming>[];
  final List<String> _failedSteadyPaths = <String>[];
  late final SkeletonBenchmarkInterruptionTracker _interruptionTracker;
  late final SkeletonBenchmarkRecordBuffer _recordBuffer;
  Completer<void>? _interactionChanged;
  Completer<void>? _windowFramesReady;
  Completer<void>? _windowInteractionChanged;
  int? _windowStartMicros;
  int _windowTargetFrames = 0;
  int _windowProbePaintStart = 0;
  int _windowTransientCallbackCount = 0;
  int _invalidTrialAttempts = 0;
  int _retriedTrials = 0;
  double _refreshRate = 0;
  int _frameBudgetMicros = 0;
  bool _animationsDisabled = false;
  bool _windowIsActive = false;
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
    _interruptionTracker = SkeletonBenchmarkInterruptionTracker(
      WidgetsBinding.instance.lifecycleState,
    );
    _recordBuffer = SkeletonBenchmarkRecordBuffer(
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
    _refreshRate = view.display.refreshRate;
    if (_refreshRate.isFinite && _refreshRate > 0) {
      final frameDuration = Duration.microsecondsPerSecond / _refreshRate;
      _frameBudgetMicros = frameDuration.floor();
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
    WidgetsBinding.instance
      ..removeObserver(this)
      ..removeTimingsCallback(_handleTimings);
    super.dispose();
  }

  Future<void> _run() async {
    var passed = false;
    try {
      await _captureValidViewMetrics();
      _validateEnvironment();
      _printEnvironment();
      for (var trial = 1; trial <= _steadyTrialCount; trial += 1) {
        final measurement = await _collectSteadyTrial(trial);
        _printSteadyResult(
          trial: trial,
          attempt: measurement.attempt,
          frames: measurement.frames,
          probePaints: measurement.probePaints,
          transientCallbackCount: measurement.transientCallbackCount,
        );
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
      throw StateError('The Skeleton benchmark must run in profile mode.');
    }
    final normalizedRenderer = _rendererName.trim().toLowerCase();
    if (normalizedRenderer.isEmpty || normalizedRenderer == 'unspecified') {
      throw StateError(
        'Set SKELETON_RENDERER to the renderer verified in device logs.',
      );
    }
    if (_runId.trim().isEmpty || _runId.trim().toLowerCase() == 'unspecified') {
      throw StateError('Set SKELETON_RUN_ID to a fresh run identifier.');
    }
    if (!_refreshRate.isFinite || _refreshRate <= 0) {
      throw StateError('The display reported an invalid refresh rate.');
    }
    if (_environmentViewMetrics == null) {
      throw StateError('The benchmark did not capture valid view metrics.');
    }
    if (_animationsDisabled) {
      throw StateError(
        'Animated Skeleton benchmarking requires platform animations to be '
        'enabled. Restore Android window, transition, and animator scales.',
      );
    }
    if (_warmupFrameCount < 1) {
      throw StateError('SKELETON_WARMUP_FRAMES must be at least one.');
    }
    if (_measuredFrameCount < 1) {
      throw StateError('SKELETON_MEASURED_FRAMES must be at least one.');
    }
    if (_cardCount < 1) {
      throw StateError('SKELETON_CARD_COUNT must be at least one.');
    }
    if (_effectName != 'fade' && _effectName != 'shimmer') {
      throw StateError('SKELETON_EFFECT must be fade or shimmer.');
    }
    if (_topologyName != 'single' && _topologyName != 'many') {
      throw StateError('SKELETON_TOPOLOGY must be single or many.');
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
      'effect': _effectName,
      'topology': _topologyName,
      'card_count': _cardCount,
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
    while (true) {
      if (!mounted) break;
      final view = View.of(context);
      final logicalSize = MediaQuery.sizeOf(context);
      final physicalSize = view.physicalSize;
      final devicePixelRatio = view.devicePixelRatio;
      final refreshRate = view.display.refreshRate;
      final logicalSizeIsValid = _sizeIsFiniteAndPositive(logicalSize);
      final physicalSizeIsValid = _sizeIsFiniteAndPositive(physicalSize);
      final devicePixelRatioIsValid = _isFiniteAndPositive(devicePixelRatio);
      final refreshRateIsValid = _isFiniteAndPositive(refreshRate);
      var allMetricsAreValid = logicalSizeIsValid && physicalSizeIsValid;
      allMetricsAreValid = allMetricsAreValid && devicePixelRatioIsValid;
      allMetricsAreValid = allMetricsAreValid && refreshRateIsValid;
      if (allMetricsAreValid) {
        _environmentViewMetrics = (
          devicePixelRatio: devicePixelRatio,
          logicalSize: logicalSize,
          physicalSize: physicalSize,
          refreshRate: refreshRate,
        );
        _refreshRate = refreshRate;
        final frameDuration = Duration.microsecondsPerSecond / refreshRate;
        _frameBudgetMicros = frameDuration.floor();
        _interruptionTracker.viewId = view.viewId;
        return;
      }

      await _waitUntilInteractive();
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    throw StateError('The Skeleton benchmark was disposed before startup.');
  }

  bool _sizeIsFiniteAndPositive(Size size) {
    final widthIsValid = _isFiniteAndPositive(size.width);
    final heightIsValid = _isFiniteAndPositive(size.height);
    return widthIsValid && heightIsValid;
  }

  bool _isFiniteAndPositive(double value) {
    return value.isFinite && value > 0;
  }

  Future<
    ({
      int attempt,
      List<FrameTiming> frames,
      int probePaints,
      int transientCallbackCount,
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
          frames: measurement.frames,
          probePaints: measurement.probePaints,
          transientCallbackCount: measurement.transientCallbackCount,
        );
      }

      _reportInvalidTrialAttempt(
        trial: trial,
        attempt: attempt,
        reasons: measurement.invalidReasons,
        collectedFrames: measurement.frames.length,
      );
    }
    throw StateError(
      'Skeleton steady trial $trial was interrupted '
      '$_maximumTrialAttempts consecutive times.',
    );
  }

  Future<void> _warmTrial() async {
    while (true) {
      await _waitUntilInteractive();
      final warmup = await _collectFrameWindow(
        targetFrames: _warmupFrameCount,
        measured: false,
      );
      if (!warmup.interrupted) return;
    }
  }

  Future<
    ({
      List<FrameTiming> frames,
      List<String> invalidReasons,
      bool interrupted,
      int probePaints,
      int transientCallbackCount,
    })
  >
  _collectFrameWindow({
    required int targetFrames,
    required bool measured,
  }) async {
    await _waitUntilInteractive();
    await _flushReportedTimings();
    if (_windowIsActive) {
      throw StateError('A Skeleton frame window was already active.');
    }

    final started = Completer<void>();
    _windowFrames.clear();
    _windowTargetFrames = targetFrames;
    _windowStartMicros = null;
    _windowFramesReady = Completer<void>();
    _windowInteractionChanged = Completer<void>();
    _windowIsActive = true;

    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!_windowIsActive) return;
      final scheduler = SchedulerBinding.instance;
      _windowStartMicros = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
      _windowProbePaintStart = _PaintProbePainter.paintCount;
      _windowTransientCallbackCount = scheduler.transientCallbackCount;
      _interruptionTracker.startWindow(collectFrames: measured);
      started.complete();
    });
    SchedulerBinding.instance.scheduleFrame();

    try {
      final startedNormally = await Future.any<bool>(<Future<bool>>[
        started.future.then((_) => true),
        _windowInteractionChanged!.future.then((_) => false),
      ]).timeout(_timingsTimeout);
      if (!startedNormally) {
        return (
          frames: const <FrameTiming>[],
          invalidReasons: const <String>[
            'interaction_changed_before_window_start',
          ],
          interrupted: true,
          probePaints: 0,
          transientCallbackCount: 0,
        );
      }

      final collectedNormally = await Future.any<bool>(<Future<bool>>[
        _windowFramesReady!.future.then((_) => true),
        _windowInteractionChanged!.future.then((_) => false),
      ]).timeout(_timingsTimeout);
      final invalidReasons = _interruptionTracker.invalidReasons;
      final interrupted = !collectedNormally || invalidReasons.isNotEmpty;
      return (
        frames: List<FrameTiming>.of(_windowFrames, growable: false),
        invalidReasons: interrupted && invalidReasons.isEmpty
            ? const <String>['interaction_changed_during_window']
            : invalidReasons,
        interrupted: interrupted,
        probePaints: _PaintProbePainter.paintCount - _windowProbePaintStart,
        transientCallbackCount: _windowTransientCallbackCount,
      );
    } finally {
      _interruptionTracker.endWindow();
      _windowIsActive = false;
      _windowStartMicros = null;
      _windowTargetFrames = 0;
      _windowFramesReady = null;
      _windowInteractionChanged = null;
    }
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
      if (_windowFrames.length >= _windowTargetFrames) break;
      _windowFrames.add(timing);
      if (_windowFrames.length == _windowTargetFrames) {
        final completer = _windowFramesReady;
        if (completer != null && !completer.isCompleted) completer.complete();
      }
    }
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
      'retrying': retrying,
      'maximum_trial_attempts': _maximumTrialAttempts,
    });
  }

  void _printSteadyResult({
    required int trial,
    required int attempt,
    required List<FrameTiming> frames,
    required int probePaints,
    required int transientCallbackCount,
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

    for (final timing in frames) {
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
    final structuralPass = probePaints == 0 && transientCallbackCount == 1;
    final path = 'steady.trial_$trial';
    if (!workFitsBudget || !structuralPass) {
      _failedSteadyPaths.add(path);
    }
    _print(<String, Object>{
      'path': path,
      'run_id': _runId,
      'effect': _effectName,
      'topology': _topologyName,
      'phase': 'steady',
      'trial': trial,
      'attempt': attempt,
      'retried': attempt > 1,
      'valid': true,
      'gate': true,
      'frames': frames.length,
      'probe_paints': probePaints,
      'transient_callbacks': transientCallbackCount,
      'build': build,
      'raster': raster,
      'total_span': _summarize(totalSpanMicros),
      'vsync_overhead': _summarize(vsyncOverheadMicros),
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
      throw StateError('Cannot summarize a frame window without timings.');
    }
    values.sort();
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return <String, num>{
      'p50_us': _percentile(values, 0.50),
      'p90_us': _percentile(values, 0.90),
      'p99_us': _percentile(values, 0.99),
      'max_us': values.last,
      'mean_us': total / values.length,
    };
  }

  int _percentile(List<int> sortedValues, double percentile) {
    final index = ((sortedValues.length * percentile).ceil() - 1).clamp(
      0,
      sortedValues.length - 1,
    );
    return sortedValues[index];
  }

  void _print(Map<String, Object> result) {
    _recordBuffer.add(result);
  }

  SkeletonEffect get _effect => switch (_effectName) {
    'fade' => const SkeletonFadeEffect(),
    'shimmer' => const SkeletonShimmerEffect(),
    _ => throw StateError('SKELETON_EFFECT must be fade or shimmer.'),
  };

  Widget _buildWorkload() {
    final cards = List<Widget>.generate(
      _cardCount,
      (index) => _BenchmarkCard(index: index),
      growable: false,
    );
    return switch (_topologyName) {
      'many' => Column(
        children: [
          for (final card in cards)
            Skeleton(
              style: SkeletonStyle(effect: _effect),
              child: card,
            ),
        ],
      ),
      'single' => Skeleton(
        style: SkeletonStyle(effect: _effect),
        child: Column(children: cards),
      ),
      _ => throw StateError('SKELETON_TOPOLOGY must be single or many.'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        body: SafeArea(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: _cardCount * 124,
              maxHeight: _cardCount * 124,
              child: SizedBox(
                height: _cardCount * 124,
                child: _buildWorkload(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
