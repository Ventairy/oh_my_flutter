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

part '_crossfade_benchmark_card.dart';
part '_crossfade_paint_probe_painter.dart';

const String _variant = String.fromEnvironment('SKELETON_SWITCH_VARIANT', defaultValue: 'unspecified');
const String _source = String.fromEnvironment('SKELETON_SWITCH_SOURCE', defaultValue: 'unspecified');
const String _renderer = String.fromEnvironment('SKELETON_SWITCH_RENDERER', defaultValue: 'unspecified');
const String _runId = String.fromEnvironment('SKELETON_SWITCH_RUN_ID', defaultValue: 'unspecified');
const String _topology = String.fromEnvironment('SKELETON_SWITCH_TOPOLOGY', defaultValue: 'many');
String get _effect => const String.fromEnvironment('SKELETON_SWITCH_EFFECT', defaultValue: 'static');
const int _cardCount = int.fromEnvironment('SKELETON_SWITCH_CARD_COUNT', defaultValue: 12);
const int _warmupSwitches = int.fromEnvironment('SKELETON_SWITCH_WARMUP_SWITCHES', defaultValue: 12);
const int _measuredSwitches = int.fromEnvironment('SKELETON_SWITCH_MEASURED_SWITCHES', defaultValue: 40);
const bool _enforceBudget = bool.fromEnvironment('SKELETON_SWITCH_ENFORCE_BUDGET');
const Duration _crossfadeDuration = Duration(milliseconds: 300);

/// A profile-mode A/B workload for [SkeletonTransition.crossfade].
class SkeletonCrossfadeBenchmark extends StatefulWidget {
  /// Creates the switch benchmark application.
  const new({super.key});

  @override
  State<SkeletonCrossfadeBenchmark> createState() => _SkeletonCrossfadeBenchmarkState();
}

class _SkeletonCrossfadeBenchmarkState extends State<SkeletonCrossfadeBenchmark> with WidgetsBindingObserver {
  static const Duration _viewTimeout = Duration(seconds: 30);
  static const Duration _timingsTimeout = Duration(seconds: 10);
  static const int _frameStartToleranceMicros = 1000;

  final List<FrameTiming> _reportedTimings = <FrameTiming>[];
  final List<({bool toSkeleton, int startMicros, List<FrameTiming> frames, int probePaints})> _samples = [];
  late final SkeletonBenchmarkInterruptionTracker _interruptionTracker;
  late final SkeletonBenchmarkRecordBuffer _records;
  late final List<Widget> _cards;
  bool _enabled = true;
  bool _animationsDisabled = false;
  double _refreshRate = 0;
  int _frameBudgetMicros = 0;
  ({double devicePixelRatio, Size logicalSize, Size physicalSize})? _viewMetrics;

  @override
  void initState() {
    super.initState();
    _cards = List<Widget>.generate(_cardCount, (index) => _CrossfadeBenchmarkCard(index: index), growable: false);
    _interruptionTracker = SkeletonBenchmarkInterruptionTracker(WidgetsBinding.instance.lifecycleState);
    _records = SkeletonBenchmarkRecordBuffer((message) => debugPrint(message, wrapWidth: 4000));
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
      _frameBudgetMicros = (Duration.microsecondsPerSecond / _refreshRate).floor();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _interruptionTracker.updateLifecycle(state);
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    _interruptionTracker.updateViewFocus(event);
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
      await _captureValidViewMetrics().timeout(_viewTimeout);
      _validateEnvironment();
      _recordEnvironment();
      for (var index = 0; index < _warmupSwitches; index += 1) {
        await _switch(measure: false);
      }
      for (var index = 0; index < _measuredSwitches; index += 1) {
        await _switch(measure: true);
      }
      final toContent = _samples.where((sample) => !sample.toSkeleton).toList(growable: false);
      final toSkeleton = _samples.where((sample) => sample.toSkeleton).toList(growable: false);
      final contentFits = _recordDirection('to_content', toContent);
      final skeletonFits = _recordDirection('to_skeleton', toSkeleton);
      passed = !_enforceBudget || contentFits && skeletonFits;
      _records.add(<String, Object>{
        'path': 'acceptance',
        'run_id': _runId,
        'variant': _variant,
        'source': _source,
        'passed': passed,
        'enforced': _enforceBudget,
        'measured_switches': _samples.length,
      });
    } on Object catch (error, stackTrace) {
      _records.add(<String, Object>{
        'path': 'error',
        'run_id': _runId,
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
      });
    } finally {
      WidgetsBinding.instance.removeTimingsCallback(_handleTimings);
      _records.flush();
      await debugPrintDone;
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await SystemNavigator.pop();
        exit(passed ? 0 : 1);
      });
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  Future<void> _captureValidViewMetrics() async {
    while (true) {
      if (!mounted) break;
      final view = View.of(context);
      final logicalSize = MediaQuery.sizeOf(context);
      final physicalSize = view.physicalSize;
      final dpr = view.devicePixelRatio;
      final refreshRate = view.display.refreshRate;
      if (_validSize(logicalSize) &&
          _validSize(physicalSize) &&
          dpr.isFinite &&
          dpr > 0 &&
          refreshRate.isFinite &&
          refreshRate > 0) {
        _viewMetrics = (devicePixelRatio: dpr, logicalSize: logicalSize, physicalSize: physicalSize);
        _refreshRate = refreshRate;
        _frameBudgetMicros = (Duration.microsecondsPerSecond / refreshRate).floor();
        return;
      }
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    throw StateError('The benchmark view was disposed before its metrics became valid.');
  }

  bool _validSize(Size size) => size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0;

  void _validateEnvironment() {
    if (!kProfileMode) throw StateError('Run the crossfade benchmark in profile mode.');
    if (_variant != 'baseline' && _variant != 'candidate') {
      throw StateError('SKELETON_SWITCH_VARIANT must be baseline or candidate.');
    }
    for (final label in <String, String>{
      'SKELETON_SWITCH_SOURCE': _source,
      'SKELETON_SWITCH_RENDERER': _renderer,
      'SKELETON_SWITCH_RUN_ID': _runId,
    }.entries) {
      if (label.value.trim().isEmpty || label.value == 'unspecified') {
        throw StateError('Set ${label.key} to a verified, non-placeholder value.');
      }
    }
    if (_topology != 'single' && _topology != 'many') {
      throw StateError('SKELETON_SWITCH_TOPOLOGY must be single or many.');
    }
    if (_effect != 'static' && _effect != 'shimmer') {
      throw StateError('SKELETON_SWITCH_EFFECT must be static or shimmer.');
    }
    if (_cardCount < 1 ||
        _warmupSwitches < 2 ||
        _measuredSwitches < 2 ||
        _warmupSwitches.isOdd ||
        _measuredSwitches.isOdd) {
      throw StateError('Card count must be positive; warmup and measured switch counts must be positive even numbers.');
    }
    if (_animationsDisabled) {
      throw StateError('Enable platform animations before measuring the crossfade.');
    }
    if (_viewMetrics == null || _frameBudgetMicros < 1) {
      throw StateError('The benchmark did not capture valid display metrics.');
    }
  }

  void _recordEnvironment() {
    final metrics = _viewMetrics!;
    _records.add(<String, Object>{
      'path': 'environment',
      'run_id': _runId,
      'variant': _variant,
      'source': _source,
      'mode': 'profile',
      'platform': defaultTargetPlatform.name,
      'operating_system': Platform.operatingSystemVersion,
      'renderer': _renderer,
      'renderer_source': 'manually verified startup or device logs',
      'topology': _topology,
      'effect': _effect,
      'card_count': _cardCount,
      'transition_duration_us': _crossfadeDuration.inMicroseconds,
      'warmup_switches': _warmupSwitches,
      'measured_switches': _measuredSwitches,
      'refresh_rate_hz': _refreshRate,
      'frame_budget_us': _frameBudgetMicros,
      'logical_size': <String, double>{'width': metrics.logicalSize.width, 'height': metrics.logicalSize.height},
      'physical_size': <String, double>{'width': metrics.physicalSize.width, 'height': metrics.physicalSize.height},
      'device_pixel_ratio': metrics.devicePixelRatio,
      'animations_disabled': _animationsDisabled,
    });
  }

  Future<void> _switch({required bool measure}) async {
    if (!_interruptionTracker.isInteractive) {
      throw StateError('The application must be resumed and the view focused before each switch.');
    }
    if (measure) {
      _interruptionTracker.startWindow(collectFrames: true);
      _reportedTimings.clear();
    }
    final toSkeleton = !_enabled;
    final paintsBefore = _CrossfadePaintProbePainter.paintCount;
    final started = Completer<int>();
    setState(() => _enabled = toSkeleton);
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      started.complete(SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds);
    });
    final startMicros = await started.future.timeout(_timingsTimeout);
    try {
      final measuredMicros = _crossfadeDuration.inMicroseconds + _frameBudgetMicros;
      await Future<void>.delayed(Duration(microseconds: measuredMicros + _frameBudgetMicros * 2));
      final paintsAfterSwitch = _CrossfadePaintProbePainter.paintCount;
      await _drainFrameTimings();
      if (!measure) return;
      final invalidReasons = _interruptionTracker.invalidReasons;
      if (invalidReasons.isNotEmpty || !_interruptionTracker.isInteractive) {
        throw StateError('Switch window interrupted: ${invalidReasons.join(', ')}');
      }
      final frames = <FrameTiming>[
        for (final timing in _reportedTimings)
          if (timing.timestampInMicroseconds(ui.FramePhase.vsyncStart) >= startMicros - _frameStartToleranceMicros &&
              timing.timestampInMicroseconds(ui.FramePhase.vsyncStart) < startMicros + measuredMicros)
            timing,
      ];
      if (frames.length < 2) {
        final firstReported = _reportedTimings.isEmpty
            ? 'none'
            : _reportedTimings.first.timestampInMicroseconds(ui.FramePhase.vsyncStart).toString();
        final lastReported = _reportedTimings.isEmpty
            ? 'none'
            : _reportedTimings.last.timestampInMicroseconds(ui.FramePhase.vsyncStart).toString();
        throw StateError(
          'Only ${frames.length} timed frames were attributed to a switch '
          '(reported=${_reportedTimings.length}, first=$firstReported, last=$lastReported, '
          'start=$startMicros, end=${startMicros + measuredMicros}).',
        );
      }
      _samples.add((
        toSkeleton: toSkeleton,
        startMicros: startMicros,
        frames: frames,
        probePaints: paintsAfterSwitch - paintsBefore,
      ));
    } finally {
      if (measure) _interruptionTracker.endWindow();
    }
  }

  Future<void> _drainFrameTimings() async {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame.timeout(_timingsTimeout);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_reportedTimings.isEmpty) throw StateError('No FrameTiming was reported after a switch.');
  }

  void _handleTimings(List<FrameTiming> timings) {
    _reportedTimings.addAll(timings);
  }

  bool _recordDirection(
    String path,
    List<({bool toSkeleton, int startMicros, List<FrameTiming> frames, int probePaints})> samples,
  ) {
    if (samples.length != _measuredSwitches ~/ 2) {
      throw StateError('Expected ${_measuredSwitches ~/ 2} $path switches; got ${samples.length}.');
    }
    final frames = <FrameTiming>[for (final sample in samples) ...sample.frames];
    final build = _statistics([for (final timing in frames) timing.buildDuration.inMicroseconds]);
    final raster = _statistics([for (final timing in frames) timing.rasterDuration.inMicroseconds]);
    final total = _statistics([for (final timing in frames) timing.totalSpan.inMicroseconds]);
    final worstBuildPerSwitch = _statistics([
      for (final sample in samples) sample.frames.map((timing) => timing.buildDuration.inMicroseconds).reduce(math.max),
    ]);
    final worstRasterPerSwitch = _statistics([
      for (final sample in samples)
        sample.frames.map((timing) => timing.rasterDuration.inMicroseconds).reduce(math.max),
    ]);
    final worstFrameStartGaps = <int>[
      for (final sample in samples)
        _maximumFrameStartGap(
          sample.frames,
          sample.startMicros,
          sample.startMicros + _crossfadeDuration.inMicroseconds,
        ),
    ];
    final worstFrameStartGapPerSwitch = _statistics(worstFrameStartGaps);
    final longFrameGapThreshold = (_frameBudgetMicros * 1.5).ceil();
    final fitsBudget = build['p99_us']! <= _frameBudgetMicros && raster['p99_us']! <= _frameBudgetMicros;
    _records.add(<String, Object>{
      'path': path,
      'run_id': _runId,
      'variant': _variant,
      'source': _source,
      'switches': samples.length,
      'frames': frames.length,
      'min_frames_per_switch': samples.map((sample) => sample.frames.length).reduce(math.min),
      'max_frames_per_switch': samples.map((sample) => sample.frames.length).reduce(math.max),
      'probe_paints': samples.fold<int>(0, (total, sample) => total + sample.probePaints),
      'build': build,
      'raster': raster,
      'total_span': total,
      'worst_build_per_switch': worstBuildPerSwitch,
      'worst_raster_per_switch': worstRasterPerSwitch,
      'worst_frame_start_gap_per_switch': worstFrameStartGapPerSwitch,
      'long_frame_gap_threshold_us': longFrameGapThreshold,
      'switches_with_long_frame_start_gap': worstFrameStartGaps.where((gap) => gap > longFrameGapThreshold).length,
      'build_over_budget': frames.where((timing) => timing.buildDuration.inMicroseconds > _frameBudgetMicros).length,
      'raster_over_budget': frames.where((timing) => timing.rasterDuration.inMicroseconds > _frameBudgetMicros).length,
      'total_span_over_budget': frames.where((timing) => timing.totalSpan.inMicroseconds > _frameBudgetMicros).length,
      'work_p99_within_budget': fitsBudget,
      'frame_budget_us': _frameBudgetMicros,
    });
    return fitsBudget;
  }

  int _maximumFrameStartGap(List<FrameTiming> frames, int startMicros, int endMicros) {
    var maximum = 0;
    var previous = startMicros;
    for (final frame in frames) {
      final current = frame.timestampInMicroseconds(ui.FramePhase.vsyncStart);
      if (current > endMicros) break;
      maximum = math.max(maximum, current - previous);
      previous = current;
    }
    return math.max(maximum, endMicros - previous);
  }

  Map<String, num> _statistics(List<int> values) {
    if (values.isEmpty) throw StateError('Cannot summarize an empty timing sample.');
    values.sort();
    final sum = values.fold<int>(0, (total, value) => total + value);
    int at(double quantile) => values[((values.length * quantile).ceil() - 1).clamp(0, values.length - 1)];
    return <String, num>{
      'p50_us': at(0.5),
      'p90_us': at(0.9),
      'p99_us': at(0.99),
      'max_us': values.last,
      'mean_us': sum / values.length,
    };
  }

  Widget _buildWorkload() {
    final style = _effect == 'shimmer' ? const SkeletonStyle(effect: SkeletonShimmerEffect()) : const SkeletonStyle();
    const transition = SkeletonTransition.crossfade();
    return switch (_topology) {
      'single' => Skeleton(
        enabled: _enabled,
        style: style,
        transition: transition,
        child: Column(children: _cards),
      ),
      'many' => Column(
        children: [
          for (final card in _cards) Skeleton(enabled: _enabled, style: style, transition: transition, child: card),
        ],
      ),
      _ => throw StateError('Invalid topology $_topology.'),
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
              child: SizedBox(height: _cardCount * 124, child: _buildWorkload()),
            ),
          ),
        ),
      ),
    );
  }
}
