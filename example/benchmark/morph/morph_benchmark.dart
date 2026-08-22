import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show FramePhase, FrameTiming, ViewFocusEvent;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'morph_benchmark_custom_flight_delegate.dart';
import 'morph_benchmark_interruption_tracker.dart';
import 'morph_benchmark_live_caret_painter.dart';
import 'morph_benchmark_multi_foreground_workload.dart';
import 'morph_benchmark_record_buffer.dart';
import 'morph_benchmark_resting_flow_delegate.dart';
import 'morph_benchmark_scenario.dart';
import 'morph_benchmark_status.dart';
import 'morph_benchmark_workloads.dart';

const bool _enforceFrameBudget = bool.fromEnvironment(
  'MORPH_ENFORCE_FRAME_BUDGET',
);
const int _steadyFramesPerTrial = int.fromEnvironment(
  'MORPH_STEADY_FRAMES_PER_TRIAL',
  defaultValue: 150,
);
const int _soakCycles = int.fromEnvironment(
  'MORPH_SOAK_CYCLES',
  defaultValue: 100,
);
const int _heapPauseSeconds = int.fromEnvironment(
  'MORPH_HEAP_PAUSE_SECONDS',
);
const int _foregroundCount = int.fromEnvironment(
  'MORPH_FOREGROUND_COUNT',
  defaultValue: 16,
);
const String _requestedScenario = String.fromEnvironment(
  'MORPH_SCENARIO',
  defaultValue: 'all',
);
const String _renderer = String.fromEnvironment(
  'MORPH_RENDERER',
  defaultValue: 'unspecified',
);
const bool _textCacheProbe = bool.fromEnvironment(
  'MORPH_TEXT_CACHE_PROBE',
);

/// Profile-mode benchmark for retained, fallback, watched, nested, and custom
/// Morph flights.
class MorphBenchmark extends StatefulWidget {
  /// Creates the Morph benchmark application.
  const MorphBenchmark({super.key});

  @override
  State<MorphBenchmark> createState() => _MorphState();
}

class _MorphState extends State<MorphBenchmark>
    with
        TickerProviderStateMixin,
        // Tracks focus and lifecycle interruptions during timing windows.
        WidgetsBindingObserver {
  static const _transitionDuration = Duration(milliseconds: 320);
  static const _nestedParentDuration = Duration(milliseconds: 640);
  static const _nestedChildDuration = Duration(milliseconds: 160);
  static const _flightTimeout = Duration(seconds: 3);
  static const _timingsTimeout = Duration(seconds: 3);
  static const _interactionTimeout = Duration(minutes: 2);
  static const _steadyTrialCount = 2;
  static const _warmupCycles = 2;
  static const _maximumTrialAttempts = 3;
  static const _maximumTransitionsPerTrial = 80;
  final List<FrameTiming> _windowFrames = <FrameTiming>[];
  final List<String> _failedSteadyPaths = <String>[];
  late final MorphBenchmarkInterruptionTracker _interruptionTracker;
  late final MorphBenchmarkRecordBuffer _recordBuffer;
  late final ui.ImageEventCallback _imageCreatedCallback;
  late final ui.ImageEventCallback _imageDisposedCallback;
  ui.ImageEventCallback? _previousImageCreatedCallback;
  ui.ImageEventCallback? _previousImageDisposedCallback;
  Completer<void>? _flightStarted;
  Completer<void>? _flightEnded;
  Completer<void>? _windowReported;
  Completer<void>? _interactionChanged;
  Stopwatch? _flightStartStopwatch;
  int? _flightStartLatencyMicros;
  int? _windowStartMicros;
  int? _windowEndMicros;
  int _latestReportedBuildStartMicros = 0;
  int _interactionVersion = 0;
  int _invalidTrialAttempts = 0;
  int _retriedTrials = 0;
  int _scenarioImageCreations = 0;
  int _scenarioImageDisposals = 0;
  int _flightImageCreations = 0;
  int _flightImagePixels = 0;
  int _largestFlightImagePixels = 0;
  bool _collectWindow = false;
  bool _collectTransitionImages = false;
  bool _scenarioIsRunning = false;
  bool _scenarioReady = false;
  bool _expanded = false;
  bool _complete = false;
  late final Widget _restingMorphEndpoints;
  late final AnimationController _restingScrollController;
  late final AnimationController _foregroundPaintController;
  late final MorphBenchmarkLiveCaretPainter _foregroundLiveCaretPainter;
  MorphBenchmarkScenario _scenario = MorphBenchmarkScenario.text;
  String _status = 'Preparing Morph benchmark…';
  double _refreshRate = 60;
  int _frameBudgetMicros = 16666;

  @override
  void initState() {
    super.initState();
    const restingColors = <Color>[
      Color(0xFFE8F1FF),
      Color(0xFFFFF0E6),
    ];
    _restingMorphEndpoints = SizedBox(
      width: 360,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: List<Widget>.generate(
          40,
          (index) => Morph(
            tag: 'benchmark-resting-endpoint-$index',
            child: Container(
              width: 68,
              height: 34,
              color: restingColors[index % restingColors.length],
            ),
          ),
          growable: false,
        ),
      ),
    );
    _restingScrollController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    );
    _foregroundPaintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _foregroundLiveCaretPainter = MorphBenchmarkLiveCaretPainter(
      _foregroundPaintController,
    );
    if (_steadyFramesPerTrial < 1) {
      throw ArgumentError.value(
        _steadyFramesPerTrial,
        'MORPH_STEADY_FRAMES_PER_TRIAL',
        'must be at least one',
      );
    }
    if (_foregroundCount < 1) {
      throw ArgumentError.value(
        _foregroundCount,
        'MORPH_FOREGROUND_COUNT',
        'must be at least one',
      );
    }
    _interruptionTracker = MorphBenchmarkInterruptionTracker(
      WidgetsBinding.instance.lifecycleState,
    );
    _recordBuffer = MorphBenchmarkRecordBuffer(
      (message) => debugPrint(message, wrapWidth: 4000),
    );
    _imageCreatedCallback = _handleImageCreated;
    _imageDisposedCallback = _handleImageDisposed;
    _previousImageCreatedCallback = ui.Image.onCreate;
    _previousImageDisposedCallback = ui.Image.onDispose;
    ui.Image.onCreate = _imageCreatedCallback;
    ui.Image.onDispose = _imageDisposedCallback;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addTimingsCallback(_handleTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRate = View.of(context).display.refreshRate;
    _interruptionTracker.viewId = View.of(context).viewId;
    if (_refreshRate.isFinite && _refreshRate > 0) {
      const microsPerSecond = Duration.microsecondsPerSecond;
      _frameBudgetMicros = (microsPerSecond / _refreshRate).floor();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.removeTimingsCallback(_handleTimings);
    if (identical(ui.Image.onCreate, _imageCreatedCallback)) {
      ui.Image.onCreate = _previousImageCreatedCallback;
    }
    if (identical(ui.Image.onDispose, _imageDisposedCallback)) {
      ui.Image.onDispose = _previousImageDisposedCallback;
    }
    _restingScrollController.dispose();
    _foregroundPaintController.dispose();
    super.dispose();
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

  Future<void> _run() async {
    var passed = false;
    try {
      _validateEnvironment();
      final scenarios = _selectedScenarios();
      await _warmEngine();
      _printEnvironment(scenarios);
      for (final scenario in scenarios) {
        await _runScenario(scenario);
      }
      if (_soakCycles > 0) {
        final soakScenario = MorphBenchmarkScenario.soakTargetFor(
          _requestedScenario,
        );
        await _runSoak(soakScenario);
      }
      passed = _failedSteadyPaths.isEmpty;
      _print(<String, Object>{
        'path': 'acceptance',
        'passed': passed,
        'enforced': _enforceFrameBudget,
        'failed_steady_paths': _failedSteadyPaths,
        'steady_trials': _steadyTrialCount,
        'steady_frames_per_trial': _steadyFramesPerTrial,
        'maximum_trial_attempts': _maximumTrialAttempts,
        'invalid_trial_attempts': _invalidTrialAttempts,
        'retried_trials': _retriedTrials,
        'soak_cycles': _soakCycles,
      });
      if (mounted) {
        setState(() {
          _complete = true;
          if (passed) {
            _status = 'Benchmark passed.';
          } else {
            _status = 'Benchmark exceeded the frame budget.';
          }
        });
      }
    } on Object catch (error, stackTrace) {
      _print(<String, Object>{
        'path': 'error',
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
      });
      if (mounted) {
        setState(() {
          _complete = true;
          _status = 'Benchmark failed: $error';
        });
      }
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

  List<MorphBenchmarkScenario> _selectedScenarios() {
    return MorphBenchmarkScenario.selectedFrom(_requestedScenario);
  }

  void _validateEnvironment() {
    if (!kProfileMode) {
      throw StateError('The Morph benchmark must run in profile mode.');
    }
    if (_renderer == 'unspecified') {
      throw StateError(
        'Set MORPH_RENDERER to the renderer verified in device startup logs.',
      );
    }
    if (!_refreshRate.isFinite || _refreshRate <= 0) {
      throw StateError('The display reported an invalid refresh rate.');
    }
  }

  Future<void> _warmEngine() async {
    for (var frame = 0; frame < 30; frame += 1) {
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<void> _runScenario(MorphBenchmarkScenario scenario) async {
    final scenarioId = scenario.id;
    _scenarioIsRunning = true;
    _scenarioImageCreations = 0;
    _scenarioImageDisposals = 0;
    _flightImageCreations = 0;
    _flightImagePixels = 0;
    _largestFlightImagePixels = 0;
    _restingScrollController.value = 0;
    setState(() {
      _scenario = scenario;
      _scenarioReady = true;
      _expanded = false;
      _status = 'Benchmarking $scenarioId…';
    });
    await SchedulerBinding.instance.endOfFrame;
    _setForegroundPaintActive(
      scenario == MorphBenchmarkScenario.foregroundMultiMixed,
    );
    await _flushReportedTimings();

    final cold = await _collectColdTrial(scenarioId);
    _printResult(
      scenario: scenarioId,
      phase: 'cold',
      direction: 'forward',
      trial: 0,
      transitions: 1,
      frames: cold.forward,
      startLatenciesMicros: <int>[cold.forwardStartLatencyMicros],
      gate: false,
      attempt: cold.attempt,
      transitionFrameCounts: <int>[cold.forward.length],
      sampleSemantics: 'initial_forward',
    );
    _printResult(
      scenario: scenarioId,
      phase: 'cold',
      direction: 'reverse',
      trial: 0,
      transitions: 1,
      frames: cold.reverse,
      startLatenciesMicros: <int>[cold.reverseStartLatencyMicros],
      gate: false,
      attempt: cold.attempt,
      transitionFrameCounts: <int>[cold.reverse.length],
      sampleSemantics: 'first_reverse_after_forward',
    );

    for (var cycle = 0; cycle < _warmupCycles; cycle += 1) {
      await _runTransition(direction: 'forward', collect: false);
      await _runTransition(direction: 'reverse', collect: false);
    }

    final combinedForward = <FrameTiming>[];
    final combinedReverse = <FrameTiming>[];
    final combinedForwardBatchFrames = <int>[];
    final combinedReverseBatchFrames = <int>[];
    final combinedForwardStartLatencies = <int>[];
    final combinedReverseStartLatencies = <int>[];
    for (var trial = 1; trial <= _steadyTrialCount; trial += 1) {
      final steady = await _collectSteadyTrial(
        scenario: scenarioId,
        trial: trial,
      );
      combinedForward.addAll(steady.forward);
      combinedReverse.addAll(steady.reverse);
      combinedForwardBatchFrames.addAll(steady.forwardBatchFrames);
      combinedReverseBatchFrames.addAll(steady.reverseBatchFrames);
      combinedForwardStartLatencies.addAll(steady.forwardStartLatenciesMicros);
      combinedReverseStartLatencies.addAll(steady.reverseStartLatenciesMicros);
      _printResult(
        scenario: scenarioId,
        phase: 'steady',
        direction: 'forward',
        trial: trial,
        transitions: steady.forwardTransitions,
        frames: steady.forward,
        startLatenciesMicros: steady.forwardStartLatenciesMicros,
        gate: true,
        attempt: steady.attempt,
        transitionFrameCounts: steady.forwardBatchFrames,
      );
      _printResult(
        scenario: scenarioId,
        phase: 'steady',
        direction: 'reverse',
        trial: trial,
        transitions: steady.reverseTransitions,
        frames: steady.reverse,
        startLatenciesMicros: steady.reverseStartLatenciesMicros,
        gate: true,
        attempt: steady.attempt,
        transitionFrameCounts: steady.reverseBatchFrames,
      );
      await _flushReportedTimings();
    }

    _printResult(
      scenario: scenarioId,
      phase: 'steady_combined',
      direction: 'forward',
      trial: 0,
      transitions: 0,
      frames: combinedForward,
      startLatenciesMicros: combinedForwardStartLatencies,
      gate: false,
      transitionFrameCounts: combinedForwardBatchFrames,
    );
    _printResult(
      scenario: scenarioId,
      phase: 'steady_combined',
      direction: 'reverse',
      trial: 0,
      transitions: 0,
      frames: combinedReverse,
      startLatenciesMicros: combinedReverseStartLatencies,
      gate: false,
      transitionFrameCounts: combinedReverseBatchFrames,
    );
    _scenarioIsRunning = false;
    _print(<String, Object>{
      'path': '$scenarioId.raster_cache_images',
      'scenario': scenarioId,
      'created_during_scenario': _scenarioImageCreations,
      'disposed_during_scenario': _scenarioImageDisposals,
      'created_during_flights': _flightImageCreations,
      'flight_image_pixels': _flightImagePixels,
      'largest_flight_image_pixels': _largestFlightImagePixels,
      'attribution': 'temporal process-wide ui.Image callbacks',
    });
    _setForegroundPaintActive(false);
  }

  void _setForegroundPaintActive(bool active) {
    if (active) {
      if (!_foregroundPaintController.isAnimating) {
        _foregroundPaintController.repeat();
      }
      return;
    }
    _foregroundPaintController.stop();
    if (_foregroundPaintController.value != 0) {
      _foregroundPaintController.value = 0;
    }
  }

  void _handleImageCreated(ui.Image image) {
    _previousImageCreatedCallback?.call(image);
    if (!_scenarioIsRunning) return;
    _scenarioImageCreations += 1;
    if (!_collectTransitionImages) return;
    final pixels = image.width * image.height;
    _flightImageCreations += 1;
    _flightImagePixels += pixels;
    _largestFlightImagePixels = math.max(_largestFlightImagePixels, pixels);
  }

  void _handleImageDisposed(ui.Image image) {
    _previousImageDisposedCallback?.call(image);
    if (_scenarioIsRunning) _scenarioImageDisposals += 1;
  }

  Future<
    ({
      List<FrameTiming> forward,
      List<FrameTiming> reverse,
      int forwardStartLatencyMicros,
      int reverseStartLatencyMicros,
      int attempt,
    })
  >
  _collectColdTrial(String scenario) async {
    for (var attempt = 1; attempt <= _maximumTrialAttempts; attempt += 1) {
      await _ensureCollapsed();
      final forward = await _runTransition(
        direction: 'forward',
        collect: true,
      );
      if (forward.invalidReasons.isNotEmpty) {
        _reportInvalidTrialAttempt(
          scenario: scenario,
          phase: 'cold',
          trial: 0,
          attempt: attempt,
          direction: 'forward',
          reasons: forward.invalidReasons,
          forwardFrames: forward.frames.length,
          reverseFrames: 0,
        );
        await _ensureCollapsed();
        continue;
      }

      final reverse = await _runTransition(
        direction: 'reverse',
        collect: true,
      );
      if (reverse.invalidReasons.isNotEmpty) {
        _reportInvalidTrialAttempt(
          scenario: scenario,
          phase: 'cold',
          trial: 0,
          attempt: attempt,
          direction: 'reverse',
          reasons: reverse.invalidReasons,
          forwardFrames: forward.frames.length,
          reverseFrames: reverse.frames.length,
        );
        continue;
      }

      return (
        forward: forward.frames,
        reverse: reverse.frames,
        forwardStartLatencyMicros: forward.startLatencyMicros,
        reverseStartLatencyMicros: reverse.startLatencyMicros,
        attempt: attempt,
      );
    }
    throw StateError(
      'The $scenario cold trial was interrupted '
      '$_maximumTrialAttempts consecutive times.',
    );
  }

  Future<
    ({
      List<FrameTiming> forward,
      List<FrameTiming> reverse,
      int forwardTransitions,
      int reverseTransitions,
      List<int> forwardBatchFrames,
      List<int> reverseBatchFrames,
      List<int> forwardStartLatenciesMicros,
      List<int> reverseStartLatenciesMicros,
      int attempt,
    })
  >
  _collectSteadyTrial({
    required String scenario,
    required int trial,
  }) async {
    for (var attempt = 1; attempt <= _maximumTrialAttempts; attempt += 1) {
      await _ensureCollapsed();
      final forward = <FrameTiming>[];
      final reverse = <FrameTiming>[];
      final forwardBatchFrames = <int>[];
      final reverseBatchFrames = <int>[];
      final forwardStartLatenciesMicros = <int>[];
      final reverseStartLatenciesMicros = <int>[];
      var forwardTransitions = 0;
      var reverseTransitions = 0;
      var invalid = false;
      while (true) {
        final needsForward = forward.length < _steadyFramesPerTrial;
        final needsReverse = reverse.length < _steadyFramesPerTrial;
        if (!needsForward && !needsReverse) break;
        final transitions = forwardTransitions + reverseTransitions;
        if (transitions >= _maximumTransitionsPerTrial) {
          throw StateError(
            'Could not collect $_steadyFramesPerTrial $scenario frames per '
            'direction after '
            '$_maximumTransitionsPerTrial transitions.',
          );
        }
        final direction = _expanded ? 'reverse' : 'forward';
        final target = direction == 'forward' ? forward : reverse;
        final collect = target.length < _steadyFramesPerTrial;
        final measurement = await _runTransition(
          direction: direction,
          collect: collect,
        );
        if (direction == 'forward') {
          forwardTransitions += 1;
        } else {
          reverseTransitions += 1;
        }
        if (measurement.invalidReasons.isNotEmpty) {
          var invalidForwardFrames = forward.length;
          var invalidReverseFrames = reverse.length;
          if (direction == 'forward') {
            invalidForwardFrames += measurement.frames.length;
          } else {
            invalidReverseFrames += measurement.frames.length;
          }
          _reportInvalidTrialAttempt(
            scenario: scenario,
            phase: 'steady',
            trial: trial,
            attempt: attempt,
            direction: direction,
            reasons: measurement.invalidReasons,
            forwardFrames: invalidForwardFrames,
            reverseFrames: invalidReverseFrames,
          );
          invalid = true;
          break;
        }
        final measuredFrames = measurement.frames;
        target.addAll(measuredFrames);
        if (direction == 'forward') {
          forwardBatchFrames.add(measuredFrames.length);
          forwardStartLatenciesMicros.add(measurement.startLatencyMicros);
        } else {
          reverseBatchFrames.add(measuredFrames.length);
          reverseStartLatenciesMicros.add(measurement.startLatencyMicros);
        }
      }
      if (invalid) {
        await _ensureCollapsed();
        continue;
      }
      return (
        forward: forward,
        reverse: reverse,
        forwardTransitions: forwardTransitions,
        reverseTransitions: reverseTransitions,
        forwardBatchFrames: forwardBatchFrames,
        reverseBatchFrames: reverseBatchFrames,
        forwardStartLatenciesMicros: forwardStartLatenciesMicros,
        reverseStartLatenciesMicros: reverseStartLatenciesMicros,
        attempt: attempt,
      );
    }
    throw StateError(
      'The $scenario steady trial $trial was interrupted '
      '$_maximumTrialAttempts consecutive times.',
    );
  }

  void _reportInvalidTrialAttempt({
    required String scenario,
    required String phase,
    required int trial,
    required int attempt,
    required String direction,
    required List<String> reasons,
    required int forwardFrames,
    required int reverseFrames,
  }) {
    final retrying = attempt < _maximumTrialAttempts;
    _invalidTrialAttempts += 1;
    if (attempt == 1 && retrying) _retriedTrials += 1;
    final trialPath = trial == 0 ? phase : '$phase.trial_$trial';
    _print(<String, Object>{
      'path': '$scenario.$trialPath.invalid.attempt_$attempt',
      'scenario': scenario,
      'phase': phase,
      if (trial != 0) 'trial': trial,
      'attempt': attempt,
      'valid': false,
      'invalid_direction': direction,
      'invalid_reasons': reasons,
      'collected_frames': <String, int>{
        'forward': forwardFrames,
        'reverse': reverseFrames,
      },
      'retrying': retrying,
      'maximum_trial_attempts': _maximumTrialAttempts,
    });
  }

  Future<void> _ensureCollapsed() async {
    await _waitUntilInteractive();
    if (!_expanded) return;
    await _runTransition(direction: 'reverse', collect: false);
  }

  Future<void> _runSoak(MorphBenchmarkScenario scenario) async {
    _setForegroundPaintActive(false);
    await _ensureCollapsed();
    final scenarioId = scenario.id;
    setState(() {
      _scenario = scenario;
      _expanded = false;
      _status = 'Running $_soakCycles $scenarioId soak cycles…';
    });
    await SchedulerBinding.instance.endOfFrame;
    await _flushReportedTimings();
    await _pauseForHeapSnapshot(
      scenario: scenarioId,
      phase: 'baseline_ready',
    );
    final mixed = scenario == MorphBenchmarkScenario.foregroundMultiMixed;
    _setForegroundPaintActive(mixed);
    if (mixed) {
      await SchedulerBinding.instance.endOfFrame;
      await _flushReportedTimings();
    }
    final creationsBefore = _scenarioImageCreations;
    final disposalsBefore = _scenarioImageDisposals;
    _scenarioIsRunning = true;
    final stopwatch = Stopwatch()..start();
    try {
      for (var cycle = 0; cycle < _soakCycles; cycle += 1) {
        await _runTransition(direction: 'forward', collect: false);
        await _runTransition(direction: 'reverse', collect: false);
      }
    } finally {
      _scenarioIsRunning = false;
      _setForegroundPaintActive(false);
    }
    stopwatch.stop();
    final soakImageCreations = _scenarioImageCreations - creationsBefore;
    final soakImageDisposals = _scenarioImageDisposals - disposalsBefore;
    _print(<String, Object>{
      'path': '$scenarioId.soak',
      'scenario': scenarioId,
      'cycles': _soakCycles,
      'transitions': _soakCycles * 2,
      'elapsed_ms': stopwatch.elapsedMilliseconds,
      'created_during_soak': soakImageCreations,
      'disposed_during_soak': soakImageDisposals,
    });
    await _pauseForHeapSnapshot(
      scenario: scenarioId,
      phase: 'soak_complete',
    );
  }

  Future<void> _pauseForHeapSnapshot({
    required String scenario,
    required String phase,
  }) async {
    if (_heapPauseSeconds <= 0) return;
    _print(<String, Object>{
      'path': '$scenario.heap.$phase',
      'pause_seconds': _heapPauseSeconds,
    });
    _recordBuffer.flush();
    await debugPrintDone;
    await Future<void>.delayed(
      Duration(seconds: math.max(_heapPauseSeconds, 1)),
    );
  }

  Future<
    ({
      List<FrameTiming> frames,
      List<String> invalidReasons,
      int startLatencyMicros,
    })
  >
  _runTransition({
    required String direction,
    required bool collect,
  }) async {
    await _waitUntilInteractive();
    final expectedDirection = _expanded ? 'reverse' : 'forward';
    if (direction != expectedDirection) {
      throw StateError(
        'Expected a $expectedDirection transition, got $direction.',
      );
    }
    final flightIsActive = _flightStarted != null || _flightEnded != null;
    final hasActiveWindow = flightIsActive || _windowReported != null;
    if (hasActiveWindow) {
      throw StateError('A Morph measurement window was already active.');
    }

    _flightStarted = Completer<void>();
    _flightEnded = Completer<void>();
    _windowReported = Completer<void>();
    _windowStartMicros = null;
    _windowEndMicros = null;
    _flightStartLatencyMicros = null;
    _windowFrames.clear();
    _collectWindow = collect;
    _collectTransitionImages = true;
    try {
      if (_scenario == MorphBenchmarkScenario.restingScroll) {
        _flightStartStopwatch = Stopwatch()..start();
        _startRestingScrollTransition();
      } else {
        _flightStartStopwatch = Stopwatch()..start();
        setState(() => _expanded = !_expanded);
      }

      await _awaitFlightSignal(
        _flightStarted!,
        timeoutMessage:
            'Morph $direction did not start. Confirm that device animations '
            'are '
            'enabled.',
      );
      await _awaitFlightSignal(
        _flightEnded!,
        timeoutMessage: 'Morph $direction did not end.',
      );
      await _awaitWindowReported();

      final frames = List<FrameTiming>.of(_windowFrames, growable: false);
      final invalidReasons = _interruptionTracker.invalidReasons;
      if (collect && frames.isEmpty && invalidReasons.isEmpty) {
        throw StateError(
          'Morph $direction produced no attributable frame timings.',
        );
      }
      final startLatencyMicros = _flightStartLatencyMicros;
      if (startLatencyMicros == null) {
        throw StateError('Morph $direction did not report its start latency.');
      }
      return (
        frames: frames,
        invalidReasons: invalidReasons,
        startLatencyMicros: startLatencyMicros,
      );
    } finally {
      _interruptionTracker.endWindow();
      _flightStarted = null;
      _flightEnded = null;
      _windowReported = null;
      _windowStartMicros = null;
      _windowEndMicros = null;
      _flightStartStopwatch = null;
      _flightStartLatencyMicros = null;
      _windowFrames.clear();
      _collectWindow = false;
      _collectTransitionImages = false;
    }
  }

  void _handleFlightStarted() {
    final completer = _flightStarted;
    if (completer == null || completer.isCompleted) return;
    final stopwatch = _flightStartStopwatch;
    if (stopwatch != null) {
      stopwatch.stop();
      _flightStartLatencyMicros = stopwatch.elapsedMicroseconds;
    }
    final scheduler = SchedulerBinding.instance;
    _windowStartMicros = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
    _interruptionTracker.startWindow(collectFrames: _collectWindow);
    completer.complete();
  }

  void _startRestingScrollTransition() {
    _expanded = !_expanded;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final started = _flightStarted;
      if (started == null || started.isCompleted) return;
      late final VoidCallback handleFirstTick;
      handleFirstTick = () {
        _restingScrollController.removeListener(handleFirstTick);
        _handleFlightStarted();
      };
      _restingScrollController.addListener(handleFirstTick);
      late final TickerFuture transition;
      if (_expanded) {
        transition = _restingScrollController.forward();
      } else {
        transition = _restingScrollController.reverse();
      }
      transition.whenCompleteOrCancel(() {
        _restingScrollController.removeListener(handleFirstTick);
        _handleFlightEnded();
      });
      unawaited(transition);
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  void _handleFlightEnded() {
    final completer = _flightEnded;
    if (completer == null || completer.isCompleted) return;
    final scheduler = SchedulerBinding.instance;
    _windowEndMicros = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
    _interruptionTracker.endWindow();
    completer.complete();
    _completeReportedWindowIfReady();
  }

  void _handleTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final buildStart = timing.timestampInMicroseconds(
        FramePhase.buildStart,
      );
      _latestReportedBuildStartMicros = math.max(
        _latestReportedBuildStartMicros,
        buildStart,
      );
      final windowStart = _windowStartMicros;
      if (windowStart == null || buildStart < windowStart) continue;
      final windowEnd = _windowEndMicros;
      if (windowEnd != null && buildStart > windowEnd) continue;
      if (_collectWindow) _windowFrames.add(timing);
    }
    _completeReportedWindowIfReady();
  }

  void _completeReportedWindowIfReady() {
    final windowEnd = _windowEndMicros;
    final completer = _windowReported;
    if (windowEnd == null || completer == null || completer.isCompleted) return;
    if (_latestReportedBuildStartMicros >= windowEnd) completer.complete();
  }

  Future<void> _awaitWindowReported() async {
    await _waitUntilInteractive();
    final completer = _windowReported!;
    for (var frame = 0; frame < 3 && !completer.isCompleted; frame += 1) {
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await completer.future.timeout(
      _timingsTimeout,
      onTimeout: () => throw TimeoutException(
        'Flutter did not report the completed Morph frame window.',
        _timingsTimeout,
      ),
    );
  }

  Future<void> _flushReportedTimings() async {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 32));
  }

  Future<void> _awaitFlightSignal(
    Completer<void> completer, {
    required String timeoutMessage,
  }) async {
    while (!completer.isCompleted) {
      await _waitUntilInteractive();
      final interactionVersion = _interactionVersion;
      try {
        await completer.future.timeout(_flightTimeout);
      } on TimeoutException {
        if (interactionVersion != _interactionVersion) continue;
        if (!_interruptionTracker.isInteractive) continue;
        throw TimeoutException(timeoutMessage, _flightTimeout);
      }
    }
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
    _interactionVersion += 1;
    final completer = _interactionChanged;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _printEnvironment(List<MorphBenchmarkScenario> scenarios) {
    final view = View.of(context);
    final logicalSize = MediaQuery.sizeOf(context);
    final scenarioIds = <String>[
      for (final scenario in scenarios) scenario.id,
    ];
    _print(<String, Object>{
      'path': 'environment',
      'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
      'platform': defaultTargetPlatform.name,
      'operating_system': Platform.operatingSystemVersion,
      'renderer': _renderer,
      'renderer_source': 'manually verified startup or device logs',
      'refresh_rate_hz': _refreshRate,
      'frame_budget_us': _frameBudgetMicros,
      'logical_size': <String, double>{
        'width': logicalSize.width,
        'height': logicalSize.height,
      },
      'physical_size': <String, double>{
        'width': view.physicalSize.width,
        'height': view.physicalSize.height,
      },
      'device_pixel_ratio': view.devicePixelRatio,
      'scenarios': scenarioIds,
      'steady_trials': _steadyTrialCount,
      'steady_frames_per_trial': _steadyFramesPerTrial,
      'maximum_trial_attempts': _maximumTrialAttempts,
      'soak_cycles': _soakCycles,
      'heap_pause_seconds': _heapPauseSeconds,
      'foreground_count': _foregroundCount,
      'text_cache_probe': _textCacheProbe,
    });
  }

  void _printResult({
    required String scenario,
    required String phase,
    required String direction,
    required int trial,
    required int transitions,
    required List<FrameTiming> frames,
    required bool gate,
    List<int> startLatenciesMicros = const <int>[],
    int attempt = 1,
    List<int> transitionFrameCounts = const <int>[],
    String? sampleSemantics,
  }) {
    final build = <int>[];
    final raster = <int>[];
    final totalSpan = <int>[];
    final vsyncOverhead = <int>[];
    var buildOverBudget = 0;
    var rasterOverBudget = 0;
    var totalSpanOverBudget = 0;
    var anyOverBudget = 0;
    var longestConsecutiveMisses = 0;
    var consecutiveMisses = 0;
    assert(
      () {
        final countedFrames = transitionFrameCounts.fold<int>(
          0,
          (sum, count) => sum + count,
        );
        return transitionFrameCounts.isEmpty || countedFrames == frames.length;
      }(),
      'Transition frame counts must cover every reported frame.',
    );
    var transitionIndex = 0;
    var transitionEnd = frames.length;
    if (transitionFrameCounts.isNotEmpty) {
      transitionEnd = transitionFrameCounts.first;
    }
    for (var frameIndex = 0; frameIndex < frames.length; frameIndex += 1) {
      if (frameIndex == transitionEnd) {
        consecutiveMisses = 0;
        transitionIndex += 1;
        transitionEnd += transitionFrameCounts[transitionIndex];
      }
      final timing = frames[frameIndex];
      final buildMicros = timing.buildDuration.inMicroseconds;
      final rasterMicros = timing.rasterDuration.inMicroseconds;
      final totalSpanMicros = timing.totalSpan.inMicroseconds;
      final vsyncOverheadMicros = timing.vsyncOverhead.inMicroseconds;
      build.add(buildMicros);
      raster.add(rasterMicros);
      totalSpan.add(totalSpanMicros);
      vsyncOverhead.add(vsyncOverheadMicros);
      if (buildMicros > _frameBudgetMicros) buildOverBudget += 1;
      if (rasterMicros > _frameBudgetMicros) rasterOverBudget += 1;
      if (totalSpanMicros > _frameBudgetMicros) totalSpanOverBudget += 1;
      final buildMissed = buildMicros > _frameBudgetMicros;
      final rasterMissed = rasterMicros > _frameBudgetMicros;
      final totalSpanMissed = totalSpanMicros > _frameBudgetMicros;
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
    build.sort();
    raster.sort();
    totalSpan.sort();
    vsyncOverhead.sort();
    final buildStats = _statistics(build);
    final rasterStats = _statistics(raster);
    final totalSpanStats = _statistics(totalSpan);
    final buildFitsBudget = buildStats['p99']! <= _frameBudgetMicros;
    final rasterFitsBudget = rasterStats['p99']! <= _frameBudgetMicros;
    final workFitsBudget = buildFitsBudget && rasterFitsBudget;
    final trialSuffix = trial == 0 ? '' : '.trial_$trial';
    final path = '$scenario.$phase.$direction$trialSuffix';
    if (gate && !workFitsBudget) _failedSteadyPaths.add(path);
    _print(<String, Object>{
      'path': path,
      'scenario': scenario,
      'phase': phase,
      'direction': direction,
      if (trial != 0) 'trial': trial,
      'attempt': attempt,
      'retried': attempt > 1,
      'sample_semantics': ?sampleSemantics,
      if (transitions != 0) 'transitions': transitions,
      'frames': frames.length,
      if (startLatenciesMicros.isNotEmpty)
        'trigger_to_on_start_us': _statistics(
          List<int>.of(startLatenciesMicros)..sort(),
        ),
      'build_us': buildStats,
      'raster_us': rasterStats,
      'total_span_us': totalSpanStats,
      'vsync_overhead_us': _statistics(vsyncOverhead),
      'build_over_budget': buildOverBudget,
      'raster_over_budget': rasterOverBudget,
      'total_span_over_budget': totalSpanOverBudget,
      'any_over_budget': anyOverBudget,
      'longest_consecutive_misses': longestConsecutiveMisses,
      'work_p99_within_budget': workFitsBudget,
      'frame_budget_us': _frameBudgetMicros,
      'gate': gate,
    });
  }

  Map<String, num> _statistics(List<int> values) {
    if (values.isEmpty) {
      throw StateError('Cannot calculate benchmark statistics without frames.');
    }
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return <String, num>{
      'average': total / values.length,
      'p50': _percentile(values, 0.50),
      'p90': _percentile(values, 0.90),
      'p99': _percentile(values, 0.99),
      'worst': values.last,
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF1F2F4),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildScenario()),
              if (_complete)
                MorphBenchmarkStatus(
                  complete: true,
                  status: _status,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenario() {
    if (!_scenarioReady) return const SizedBox.shrink();
    return switch (_scenario) {
      MorphBenchmarkScenario.text => _buildTextScenario(),
      MorphBenchmarkScenario.column => _buildColumnScenario(),
      MorphBenchmarkScenario.surface => _buildSurfaceScenario(),
      MorphBenchmarkScenario.foregroundStatic => _buildForegroundScenario(
        live: false,
      ),
      MorphBenchmarkScenario.foregroundLive => _buildForegroundScenario(
        live: true,
      ),
      MorphBenchmarkScenario.foregroundMultiStatic => _buildMultiStatic(),
      MorphBenchmarkScenario.foregroundMultiMixed => _buildMultiMixed(),
      MorphBenchmarkScenario.foregroundFallbackStatic => _buildFallback(false),
      MorphBenchmarkScenario.foregroundFallbackLive => _buildFallback(true),
      MorphBenchmarkScenario.watchText => _buildWatchTextScenario(),
      MorphBenchmarkScenario.watchCompound => _buildWatchCompoundScenario(),
      MorphBenchmarkScenario.watchCustom => _buildWatchCustomScenario(),
      MorphBenchmarkScenario.watchStationary => _buildStationaryWatch(),
      MorphBenchmarkScenario.watchStationaryControl => _buildStationaryWatch(),
      MorphBenchmarkScenario.restingScroll => _buildRestingScrollScenario(),
      MorphBenchmarkScenario.rawDescendants => _buildRawDescendantsScenario(
        fade: false,
      ),
      MorphBenchmarkScenario.rawDescendantsFade => _buildRawDescendantsScenario(
        fade: true,
      ),
      MorphBenchmarkScenario.descendantLive => _buildDescendantScenario(
        MorphDescendantFlightBehavior.live,
      ),
      MorphBenchmarkScenario.descendantSnapshot => _buildDescendantScenario(
        MorphDescendantFlightBehavior.snapshot,
      ),
      MorphBenchmarkScenario.descendantHide => _buildDescendantScenario(
        MorphDescendantFlightBehavior.hide,
      ),
      MorphBenchmarkScenario.descendantSnapshotDense => _buildDense(),
      MorphBenchmarkScenario.columnUnmatched => _buildUnmatchedColumnScenario(),
      MorphBenchmarkScenario.columnMatchedRawResize => _buildMatchedRawResize(),
      MorphBenchmarkScenario.nestedHold => _buildNestedHoldScenario(),
      MorphBenchmarkScenario.nestedWatchHold => _buildNestedWatchHoldScenario(),
      MorphBenchmarkScenario.decoratedBackground => _buildDecoratedBoxScenario(
        position: DecorationPosition.background,
      ),
      MorphBenchmarkScenario.decoratedForeground => _buildDecoratedBoxScenario(
        position: DecorationPosition.foreground,
      ),
    };
  }

  Key _endpointKey(String id) {
    return ValueKey<String>(
      _scenario.endpointIdentity(child: id, destination: _expanded),
    );
  }

  Widget _buildWatchTextScenario() {
    var textColor = const Color(0xFF273C75);
    var alignment = const Alignment(-0.25, -0.7);
    if (_expanded) {
      textColor = const Color(0xFF192A56);
      alignment = const Alignment(0.3, 0.25);
    }
    final endpoint = Morph(
      tag: 'benchmark-watch-text',
      duration: _transitionDuration,
      watchDestination: true,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
      child: Text(
        key: _endpointKey('watch-text'),
        _expanded ? 'Destino observado em movimento' : 'Origem observada',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: _expanded ? 30 : 21,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return _buildWatchedGeometry(
      alignment: alignment,
      size: _expanded ? const Size(330, 114) : const Size(260, 74),
      child: endpoint,
    );
  }

  Widget _buildWatchCompoundScenario() {
    var surfaceColor = const Color(0xFFF8FAFF);
    var alignment = const Alignment(-0.2, -0.62);
    if (_expanded) {
      surfaceColor = const Color(0xFFE8F1FF);
      alignment = const Alignment(0.15, 0.2);
    }
    final endpoint = Morph(
      tag: 'benchmark-watch-compound',
      duration: _transitionDuration,
      watchDestination: true,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
      child: Container(
        key: _endpointKey('watch-compound'),
        padding: EdgeInsets.all(_expanded ? 24 : 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(_expanded ? 34 : 18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _expanded ? 'Composto observado' : 'Composto',
              key: const ValueKey<String>('watch-compound-title'),
              style: TextStyle(
                fontSize: _expanded ? 28 : 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _expanded
                  ? 'O destino muda de posição e tamanho durante toda a '
                        'transferência.'
                  : 'Destino em movimento.',
              key: const ValueKey<String>('watch-compound-description'),
              maxLines: _expanded ? 3 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
    return _buildWatchedGeometry(
      alignment: alignment,
      size: _expanded ? const Size(340, 300) : const Size(300, 180),
      child: endpoint,
    );
  }

  Widget _buildWatchCustomScenario() {
    final color = _expanded ? const Color(0xFF8E44AD) : const Color(0xFF16A085);
    var alignment = const Alignment(-0.35, -0.6);
    if (_expanded) alignment = const Alignment(0.35, 0.3);
    final endpoint = Morph(
      tag: 'benchmark-watch-custom',
      duration: _transitionDuration,
      watchDestination: true,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
      flightDelegate: const BenchmarkCustomFlightDelegate(),
      child: ColoredBox(
        key: _endpointKey('watch-custom'),
        color: color,
      ),
    );
    return _buildWatchedGeometry(
      alignment: alignment,
      size: _expanded ? const Size(210, 150) : const Size(120, 80),
      child: endpoint,
    );
  }

  Widget _buildStationaryWatch() {
    final scenario = _scenario;
    final watchDestination = scenario == MorphBenchmarkScenario.watchStationary;
    var tag = 'benchmark-watch-stationary-control';
    var textColor = const Color(0xFF273C75);
    var alignment = const Alignment(-0.35, -0.65);
    if (watchDestination) tag = 'benchmark-watch-stationary';
    if (_expanded) {
      textColor = const Color(0xFF192A56);
      alignment = const Alignment(0.35, 0.25);
    }
    final endpoint = Morph(
      tag: tag,
      duration: _transitionDuration,
      watchDestination: watchDestination,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
      child: Text(
        key: _endpointKey(
          watchDestination ? 'watch-stationary' : 'watch-control',
        ),
        _expanded ? 'Destino observado estável' : 'Origem observada estável',
        textAlign: TextAlign.center,
        locale: const Locale('pt', 'BR'),
        style: TextStyle(
          color: textColor,
          fontSize: _expanded ? 30 : 21,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: _expanded ? 320 : 250,
        height: _expanded ? 100 : 70,
        child: endpoint,
      ),
    );
  }

  Widget _buildRestingScrollScenario() {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 360,
        height: 400,
        child: Flow(
          clipBehavior: Clip.none,
          delegate: MorphBenchmarkRestingFlowDelegate(
            _restingScrollController,
          ),
          children: <Widget>[_restingMorphEndpoints],
        ),
      ),
    );
  }

  Widget _buildWatchedGeometry({
    required Alignment alignment,
    required Size size,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<MorphBenchmarkScenario>(_scenario),
      duration: _transitionDuration,
      tween: Tween<double>(end: _expanded ? 1 : 0),
      child: child,
      builder: (context, progress, child) {
        final pulse = math.sin(math.pi * progress);
        return Align(
          alignment: Alignment(
            alignment.x + pulse * 0.18,
            alignment.y - pulse * 0.12,
          ),
          child: SizedBox(
            width: size.width + pulse * 48,
            height: size.height + pulse * 32,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildRawDescendantsScenario({required bool fade}) {
    var surfaceColor = const Color(0xFFFFFAF4);
    final ordinaryText = _expanded
        ? 'Conteúdo comum com MediaQuery capturada no destino.'
        : 'Conteúdo comum capturado.';
    var alignment = const Alignment(-0.2, -0.65);
    if (_expanded) {
      surfaceColor = const Color(0xFFFFF4E8);
      alignment = const Alignment(0.25, 0.2);
    }
    final endpointMediaQuery =
        MediaQueryData.fromView(
          View.of(context),
        ).copyWith(
          textScaler: TextScaler.linear(_expanded ? 1.12 : 0.94),
        );
    final AnimatedSwitcherTransitionBuilder? transition = fade
        ? (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          }
        : null;
    final endpoint = Morph(
      tag: fade ? 'benchmark-raw-fade' : 'benchmark-raw-null',
      duration: _transitionDuration,
      switchTransition: transition,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
      child: Container(
        key: _endpointKey(fade ? 'raw-fade' : 'raw-null'),
        width: _expanded ? 344 : 292,
        height: _expanded ? 190 : 136,
        padding: EdgeInsets.all(_expanded ? 24 : 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(_expanded ? 30 : 18),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              _expanded ? Icons.auto_awesome : Icons.info_outline,
              size: _expanded ? 36 : 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ordinaryText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    return MediaQuery(
      data: endpointMediaQuery,
      child: Align(
        alignment: alignment,
        child: endpoint,
      ),
    );
  }

  Widget _buildDescendantScenario(
    MorphDescendantFlightBehavior behavior,
  ) {
    return MorphBenchmarkWorkloads.descendant(
      expanded: _expanded,
      behavior: behavior,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
    );
  }

  Widget _buildDense() {
    return MorphBenchmarkWorkloads.descendantSnapshotDense(
      expanded: _expanded,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
    );
  }

  Widget _buildUnmatchedColumnScenario() {
    final ordinaryKey = _expanded ? 'arriving-ordinary' : 'departing-ordinary';
    var alignment = const Alignment(-0.2, -0.65);
    if (_expanded) alignment = const Alignment(0.2, 0.2);
    final ordinaryChild = DecoratedBox(
      key: ValueKey<String>(ordinaryKey),
      decoration: BoxDecoration(
        color: _expanded ? const Color(0xFFDFF7EC) : const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(_expanded ? Icons.check_circle_outline : Icons.schedule),
            const SizedBox(width: 10),
            Text(_expanded ? 'Filho comum chegando' : 'Filho comum saindo'),
          ],
        ),
      ),
    );
    final endpoint = Morph(
      tag: 'benchmark-column-unmatched',
      duration: _transitionDuration,
      switchTransition: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
      child: Column(
        key: _endpointKey('column-unmatched'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _expanded ? 'Coluna no destino' : 'Coluna na origem',
            key: const ValueKey<String>('unmatched-column-title'),
            style: TextStyle(
              fontSize: _expanded ? 28 : 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          ordinaryChild,
        ],
      ),
    );
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: _expanded ? 340 : 290,
        height: _expanded ? 230 : 180,
        child: endpoint,
      ),
    );
  }

  Widget _buildMatchedRawResize() {
    return MorphBenchmarkWorkloads.columnMatchedRawResize(
      expanded: _expanded,
      duration: _transitionDuration,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
    );
  }

  Widget _buildNestedHoldScenario() {
    var surfaceColor = const Color(0xFFF8F9FF);
    var alignment = const Alignment(-0.18, -0.55);
    if (_expanded) {
      surfaceColor = const Color(0xFFEEF2FF);
      alignment = const Alignment(0.15, 0.15);
    }
    final endpoint = Morph(
      tag: 'benchmark-nested-parent',
      duration: _nestedParentDuration,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
      child: Container(
        key: _endpointKey('nested-parent'),
        width: _expanded ? 350 : 300,
        height: _expanded ? 420 : 300,
        padding: EdgeInsets.all(_expanded ? 28 : 18),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(_expanded ? 36 : 22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildNestedText(0),
            _buildNestedText(1),
            _buildNestedText(2),
            _buildNestedText(3),
          ],
        ),
      ),
    );
    return Align(
      alignment: alignment,
      child: endpoint,
    );
  }

  Widget _buildNestedWatchHoldScenario() {
    return MorphBenchmarkWorkloads.nestedWatchHold(
      expanded: _expanded,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
    );
  }

  Widget _buildNestedText(int index) {
    var text = 'Origem aninhada ${index + 1}';
    if (_expanded) text = 'Destino aninhado ${index + 1}';
    return Morph(
      tag: 'benchmark-nested-text-$index',
      duration: _nestedChildDuration,
      child: Text(
        key: _endpointKey('nested-text-$index'),
        text,
        style: TextStyle(
          fontSize: _expanded ? 24 : 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDecoratedBoxScenario({
    required DecorationPosition position,
  }) {
    var alignment = const Alignment(-0.2, -0.65);
    if (_expanded) alignment = const Alignment(0.2, 0.2);
    var endpointId = 'decorated-background';
    if (position == DecorationPosition.foreground) {
      endpointId = 'decorated-foreground';
    }
    final endpoint = Morph(
      tag: position == DecorationPosition.background
          ? 'benchmark-decorated-background'
          : 'benchmark-decorated-foreground',
      duration: _transitionDuration,
      onStart: _handleFlightStarted,
      onEnd: _handleFlightEnded,
      child: DecoratedBox(
        key: _endpointKey(endpointId),
        position: position,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _expanded
                ? const <Color>[Color(0xFFB8E0FF), Color(0xFF8CA6FF)]
                : const <Color>[Color(0xFFFFD6E8), Color(0xFFFFA8B8)],
          ),
          borderRadius: BorderRadius.circular(_expanded ? 38 : 18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 18,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(_expanded ? 28 : 18),
          child: Text(
            _expanded ? 'DecoratedBox no destino' : 'DecoratedBox na origem',
            textAlign: TextAlign.center,
            locale: const Locale('pt', 'BR'),
            style: TextStyle(
              color: const Color(0xFF182033),
              fontSize: _expanded ? 27 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: _expanded ? 340 : 280,
        height: _expanded ? 220 : 140,
        child: endpoint,
      ),
    );
  }

  Widget _buildTextScenario() {
    var alignment = const Alignment(0, -0.75);
    var content = 'Montar armários';
    var color = const Color(0xFF30343B);
    if (_expanded) {
      alignment = const Alignment(0, 0.25);
      content = 'Montar dois armários no apartamento';
      if (!_textCacheProbe) color = const Color(0xFF111111);
    }
    final text = Text(
      key: _endpointKey('text'),
      content,
      textAlign: TextAlign.center,
      maxLines: _expanded ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: _expanded ? 32 : 21,
        fontWeight: FontWeight.w800,
        height: _textCacheProbe || !_expanded ? 1.2 : 1.08,
      ),
    );
    return Align(
      alignment: alignment,
      child: Morph(
        tag: 'benchmark-text',
        duration: _transitionDuration,
        onStart: _handleFlightStarted,
        onEnd: _handleFlightEnded,
        child: text,
      ),
    );
  }

  Widget _buildColumnScenario() {
    return Align(
      alignment: _expanded ? const Alignment(0, 0.2) : const Alignment(0, -0.7),
      child: SizedBox(
        width: _expanded ? 330 : 280,
        height: _expanded ? 310 : 180,
        child: Morph(
          tag: 'benchmark-column',
          duration: _transitionDuration,
          onStart: _handleFlightStarted,
          onEnd: _handleFlightEnded,
          child: Column(
            key: _endpointKey('column'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _expanded ? 'Publicado hoje' : 'Hoje',
                key: const ValueKey('time'),
                style: TextStyle(fontSize: _expanded ? 15 : 13),
              ),
              Text(
                _expanded ? 'Montar dois armários' : 'Montar armários',
                key: const ValueKey('title'),
                style: TextStyle(
                  fontSize: _expanded ? 30 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _expanded ? r'Pagamento de R$ 240' : r'R$ 240',
                key: const ValueKey('payment'),
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: _expanded ? 20 : 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _expanded
                    ? 'Todas as peças estão separadas e o manual está '
                          'disponível.'
                    : 'Peças separadas e manual disponível.',
                key: const ValueKey('description'),
                maxLines: _expanded ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceScenario() {
    var title = 'Montar armários';
    var descriptionOverflow = TextOverflow.ellipsis;
    if (_expanded) {
      title = 'Montar dois armários no apartamento';
      descriptionOverflow = TextOverflow.visible;
    }
    return Align(
      alignment: _expanded ? Alignment.center : const Alignment(0, -0.72),
      child: Morph(
        tag: 'benchmark-surface',
        duration: _transitionDuration,
        onStart: _handleFlightStarted,
        onEnd: _handleFlightEnded,
        child: Container(
          key: _endpointKey('surface'),
          width: _expanded ? 340 : 320,
          height: _expanded ? 540 : 250,
          padding: EdgeInsets.all(_expanded ? 28 : 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_expanded ? 34 : 38),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _expanded ? 'Publicado hoje' : 'Hoje',
                key: const ValueKey('time'),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                key: const ValueKey('title'),
                style: TextStyle(
                  fontSize: _expanded ? 30 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _expanded ? r'Pagamento de R$ 240' : r'R$ 240',
                key: const ValueKey('payment'),
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: _expanded ? 20 : 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _expanded
                    ? 'Preciso de ajuda para montar dois armários de '
                          'madeira. Todas as peças já estão '
                          'separadas e o manual está disponível.'
                    : 'Montagem de dois armários com manual disponível.',
                key: const ValueKey('description'),
                maxLines: _expanded ? null : 2,
                overflow: descriptionOverflow,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForegroundScenario({
    required bool live,
    bool fallback = false,
  }) {
    final scenarioId = [
      'foreground',
      if (fallback) 'fallback',
      if (live) 'live' else 'static',
    ].join('-');
    var surfaceColor = const Color(0xFFFFFFFF);
    if (_expanded) surfaceColor = const Color(0xFFE8F1FF);
    final surface = Align(
      alignment: _expanded ? Alignment.center : const Alignment(0, -0.72),
      child: Morph(
        tag: 'benchmark-$scenarioId-surface',
        duration: _transitionDuration,
        switchTransition: fallback ? _buildForegroundFallbackTransition : null,
        onStart: _handleFlightStarted,
        onEnd: _handleFlightEnded,
        child: Container(
          key: _endpointKey('$scenarioId-surface'),
          width: _expanded ? 340 : 300,
          height: _expanded ? 520 : 240,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(_expanded ? 34 : 24),
          ),
          child: fallback ? const ColoredBox(color: Color(0x01000000)) : null,
        ),
      ),
    );
    final foreground = live
        ? TweenAnimationBuilder<double>(
            duration: _transitionDuration,
            tween: Tween<double>(end: _expanded ? 1 : 0),
            builder: (context, progress, child) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0x33000000),
                      blurRadius: 10 + progress * 8,
                      offset: Offset(0, 5 + progress * 3),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: _buildForegroundControl(),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 14,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: _buildForegroundControl(),
          );
    return Stack(
      children: <Widget>[
        Positioned.fill(child: surface),
        Positioned(
          left: 24,
          right: 24,
          bottom: 32,
          child: MorphForeground(child: foreground),
        ),
      ],
    );
  }

  Widget _buildFallback(bool live) {
    return _buildForegroundScenario(live: live, fallback: true);
  }

  Widget _buildMultiStatic() {
    return _buildMultiForegroundScenario(mixed: false);
  }

  Widget _buildMultiMixed() {
    return _buildMultiForegroundScenario(mixed: true);
  }

  Widget _buildMultiForegroundScenario({required bool mixed}) {
    var scenario = MorphBenchmarkScenario.foregroundMultiStatic;
    if (mixed) scenario = MorphBenchmarkScenario.foregroundMultiMixed;
    var surfaceColor = const Color(0xFFFFFFFF);
    if (_expanded) surfaceColor = const Color(0xFFE8F1FF);
    final surface = Align(
      alignment: _expanded ? Alignment.center : const Alignment(0, -0.72),
      child: Morph(
        tag: 'benchmark-${scenario.id}-surface',
        duration: _transitionDuration,
        onStart: _handleFlightStarted,
        onEnd: _handleFlightEnded,
        child: Container(
          key: _endpointKey('${scenario.id}-surface'),
          width: _expanded ? 340 : 300,
          height: _expanded ? 520 : 240,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(_expanded ? 34 : 24),
          ),
        ),
      ),
    );
    return Stack(
      children: <Widget>[
        Positioned.fill(child: surface),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: MorphBenchmarkMultiForegroundWorkload(
                count: _foregroundCount,
                mixed: mixed,
                livePainter: _foregroundLiveCaretPainter,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForegroundFallbackTransition(
    Widget child,
    Animation<double> animation,
  ) {
    return FractionalTranslation(
      translation: const Offset(0.12, 0),
      child: child,
    );
  }

  Widget _buildForegroundControl() {
    return const SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          SizedBox(width: 20),
          Icon(Icons.search, color: Color(0xFF30343B)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search for an address',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF30343B),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 20),
        ],
      ),
    );
  }
}
