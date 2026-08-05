import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'text_motion_benchmark_stage.dart';

const int _engineWarmupFrames = 180;
const int _coldFrames = 30;
const int _steadyWarmupFrames = 90;
const int _steadyFramesPerTrial = 300;
const bool _enforceFrameBudget = bool.fromEnvironment(
  'TEXT_MOTION_ENFORCE_FRAME_BUDGET',
);
const int _instanceCount = int.fromEnvironment(
  'TEXT_MOTION_INSTANCE_COUNT',
  defaultValue: 1,
);

void main() {
  if (_instanceCount < 1) {
    throw ArgumentError.value(
      _instanceCount,
      'TEXT_MOTION_INSTANCE_COUNT',
      'must be at least one',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _TextMotionBenchmarkView(),
    ),
  );
}

class _TextMotionBenchmarkView extends StatefulWidget {
  const _TextMotionBenchmarkView();

  @override
  State<_TextMotionBenchmarkView> createState() {
    return _TextMotionBenchmarkViewState();
  }
}

class _TextMotionBenchmarkViewState extends State<_TextMotionBenchmarkView> {
  static const String _text = 'Galaxy J5 • 0123456789 • smooth';
  static const TextStyle _style = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static const List<MotionEffect> _builtInEffects = <MotionEffect>[
    FadeInMotionEffect(
      duration: Duration(milliseconds: 1200),
      playback: MotionPlayback.loop,
    ),
    MoveMotionEffect(
      begin: Offset(0, 6),
      end: Offset.zero,
      duration: Duration(milliseconds: 1200),
      playback: MotionPlayback.loop,
    ),
    ScaleInMotionEffect(
      scale: 0.92,
      duration: Duration(milliseconds: 1200),
      playback: MotionPlayback.loop,
    ),
    FloatingMotionEffect(
      distance: 3,
      duration: Duration(milliseconds: 1200),
    ),
  ];
  final List<FrameTiming> _samples = <FrameTiming>[];
  final List<FrameTiming> _optimizedSteadySamples = <FrameTiming>[];
  double _refreshRate = 60;
  int _frameBudgetMicroseconds = 16666;
  late _TextMotionBenchmarkStage _stage;
  int _remainingFrames = _engineWarmupFrames;
  int _textMotionGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRate = View.of(context).display.refreshRate;
    final rate = _refreshRate > 0 ? _refreshRate : 60;
    const micros = Duration.microsecondsPerSecond;
    _frameBudgetMicroseconds = (micros / rate).floor();
  }

  @override
  void initState() {
    super.initState();
    _stage = _TextMotionBenchmarkStage.engineWarmup;
    WidgetsBinding.instance.addTimingsCallback(_handleTimings);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_handleTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: Center(child: _buildStage()),
    );
  }

  Widget _buildStage() {
    if (_stage.isEngineWarmup) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(
          _instanceCount,
          (_) => const Stack(
            alignment: Alignment.center,
            children: [
              Text(_text, maxLines: 1, style: _style),
              Motion(
                effect: FloatingMotionEffect(),
                child: SizedBox.square(dimension: 20),
              ),
            ],
          ),
          growable: false,
        ),
      );
    }

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(
          _instanceCount,
          (index) => TextMotion.list(
            key: ValueKey<(int, int)>((_textMotionGeneration, index)),
            effects: _builtInEffects,
            stagger: const Duration(milliseconds: 24),
            child: const Text(_text, maxLines: 1, style: _style),
          ),
          growable: false,
        ),
      ),
    );
  }

  void _handleTimings(List<FrameTiming> timings) {
    if (_stage.isFinished) {
      return;
    }
    for (final timing in timings) {
      if (_remainingFrames > 0) {
        _remainingFrames -= 1;
        if (_remainingFrames == 0) {
          _advanceStage();
          return;
        }
        continue;
      }
      _samples.add(timing);
      if (_samples.length < _stage.sampleFrames) {
        continue;
      }
      _recordSamples();
      _samples.clear();
      _advanceStage();
      return;
    }
  }

  void _recordSamples() {
    final reportName = _stage.reportName;
    if (reportName == null) {
      return;
    }
    if (_stage.isOptimizedSteady) {
      _optimizedSteadySamples.addAll(_samples);
    }
    _printResult(reportName, _samples);
  }

  void _advanceStage() {
    switch (_stage) {
      case _TextMotionBenchmarkStage.engineWarmup:
        _switchRenderedPath(_TextMotionBenchmarkStage.optimizedCold);
      case _TextMotionBenchmarkStage.optimizedCold:
        _startWarmup(_TextMotionBenchmarkStage.optimizedWarmupFirst);
      case _TextMotionBenchmarkStage.optimizedWarmupFirst:
        _stage = _TextMotionBenchmarkStage.optimizedSteadyFirst;
      case _TextMotionBenchmarkStage.optimizedSteadyFirst:
        _switchRenderedPath(
          _TextMotionBenchmarkStage.optimizedWarmupSecond,
          warmup: true,
        );
      case _TextMotionBenchmarkStage.optimizedWarmupSecond:
        _stage = _TextMotionBenchmarkStage.optimizedSteadySecond;
      case _TextMotionBenchmarkStage.optimizedSteadySecond:
        _finish();
      case _TextMotionBenchmarkStage.finished:
        return;
    }
  }

  void _switchRenderedPath(
    _TextMotionBenchmarkStage stage, {
    bool warmup = false,
  }) {
    setState(() {
      _stage = stage;
      _textMotionGeneration += 1;
      _remainingFrames = warmup ? _steadyWarmupFrames : 0;
    });
  }

  void _startWarmup(_TextMotionBenchmarkStage stage) {
    _stage = stage;
    _remainingFrames = _steadyWarmupFrames;
  }

  void _finish() {
    _stage = _TextMotionBenchmarkStage.finished;
    WidgetsBinding.instance.removeTimingsCallback(_handleTimings);
    final optimized = _result(
      'optimized_steady_combined',
      _optimizedSteadySamples,
    );
    _print(optimized);
    final optimizedBuild = optimized['build_us']! as Map<String, num>;
    final optimizedRaster = optimized['raster_us']! as Map<String, num>;
    final optimizedBuildP99 = optimizedBuild['p99']!;
    final optimizedRasterP99 = optimizedRaster['p99']!;
    final buildPassesBudget = optimizedBuildP99 <= _frameBudgetMicroseconds;
    final rasterPassesBudget = optimizedRasterP99 <= _frameBudgetMicroseconds;
    final passesFrameBudget = buildPassesBudget && rasterPassesBudget;
    final passed = passesFrameBudget;
    _print(<String, Object>{
      'path': 'acceptance',
      'passes_frame_budget': passesFrameBudget,
      'passed': passed,
      'enforced': _enforceFrameBudget,
      'platform': defaultTargetPlatform.name,
      'operating_system': Platform.operatingSystemVersion,
      'refresh_rate_hz': _refreshRate,
      'frame_budget_us': _frameBudgetMicroseconds,
      'instance_count': _instanceCount,
    });
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await SystemNavigator.pop();
      exit(_enforceFrameBudget && !passed ? 1 : 0);
    });
  }

  void _printResult(String path, List<FrameTiming> samples) {
    _print(_result(path, samples));
  }

  Map<String, Object> _result(String path, List<FrameTiming> samples) {
    final build = <int>[];
    final raster = <int>[];
    for (final timing in samples) {
      build.add(timing.buildDuration.inMicroseconds);
      raster.add(timing.rasterDuration.inMicroseconds);
    }
    build.sort();
    raster.sort();
    return <String, Object>{
      'path': path,
      'frames': samples.length,
      'build_us': _statistics(build),
      'raster_us': _statistics(raster),
      'build_over_budget': _countOverBudget(build),
      'raster_over_budget': _countOverBudget(raster),
    };
  }

  int _countOverBudget(List<int> values) {
    return values.where((value) => value > _frameBudgetMicroseconds).length;
  }

  Map<String, num> _statistics(List<int> values) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return <String, num>{
      'average': total / values.length,
      'p50': values[(values.length * 0.50).floor()],
      'p90': values[(values.length * 0.90).floor()],
      'p99': values[(values.length * 0.99).floor()],
      'worst': values.last,
    };
  }

  void _print(Map<String, Object> result) {
    debugPrint(
      'TEXT_MOTION_BENCHMARK ${jsonEncode(result)}',
      wrapWidth: 4000,
    );
  }
}
