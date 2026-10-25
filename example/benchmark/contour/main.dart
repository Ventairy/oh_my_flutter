import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_benchmark_color.dart';
import 'contour_benchmark_cpu_affinity.dart';
import 'contour_benchmark_generic_artwork.dart';
import 'contour_benchmark_presentation_tracker.dart';
import 'contour_benchmark_probe.dart';

/// Measures identical fixed-size content with and without contours.
void main() => runApp(
  MaterialApp(
    routes: {'/': (_) => const _ContourBenchmark()},
    // The Android route carries benchmark configuration, not a navigation path.
    // WidgetsApp otherwise prioritizes that platform route over initialRoute.
    onGenerateInitialRoutes: (_) => [
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const _ContourBenchmark(),
      ),
    ],
  ),
);

class _ContourBenchmark extends StatefulWidget {
  const new();

  @override
  State<_ContourBenchmark> createState() => _ContourBenchmarkState();
}

class _ContourBenchmarkState extends State<_ContourBenchmark> with SingleTickerProviderStateMixin {
  static final Map<String, String> _route = Uri.parse(WidgetsBinding.instance.platformDispatcher.defaultRouteName)
      .queryParameters;
  static final bool _enabled =
      bool.tryParse(_route['enabled'] ?? '') ?? const bool.fromEnvironment('CONTOUR_ENABLED', defaultValue: true);
  static final bool _warmReuse = bool.tryParse(_route['warmReuse'] ?? '') ?? false;
  static final bool _generic = bool.tryParse(_route['generic'] ?? '') ?? false;
  static final String _colorHex =
      _route['contourColor'] ?? const String.fromEnvironment('CONTOUR_COLOR', defaultValue: 'ffffffff');
  late final Color _contourColor;
  static final bool _updates = bool.tryParse(_route['updates'] ?? '') ?? const bool.fromEnvironment('CONTOUR_UPDATES');
  static final bool _unique = bool.tryParse(_route['unique'] ?? '') ?? const bool.fromEnvironment('CONTOUR_UNIQUE');
  static const List<IconData> _uniqueIcons = [
    Icons.favorite,
    Icons.star,
    Icons.home,
    Icons.shopping_bag,
    Icons.coffee,
    Icons.bolt,
    Icons.check_circle,
    Icons.thumb_up,
    Icons.pets,
    Icons.local_fire_department,
    Icons.flight,
    Icons.face,
    Icons.cake,
    Icons.wb_sunny,
    Icons.cloud,
    Icons.spa,
    Icons.music_note,
    Icons.notifications,
    Icons.bookmark,
    Icons.build,
    Icons.explore,
    Icons.camera_alt,
    Icons.lightbulb,
    Icons.diamond,
    Icons.park,
    Icons.restaurant,
    Icons.sports_soccer,
    Icons.emoji_events,
    Icons.local_florist,
    Icons.anchor,
    Icons.umbrella,
    Icons.auto_awesome,
    Icons.brush,
    Icons.cruelty_free,
    Icons.eco,
    Icons.extension,
    Icons.flag,
    Icons.rocket_launch,
    Icons.watch,
    Icons.key,
  ];
  static final bool _large = bool.tryParse(_route['large'] ?? '') ?? const bool.fromEnvironment('CONTOUR_LARGE');
  static final bool _shadows =
      bool.tryParse(_route['shadows'] ?? '') ?? const bool.fromEnvironment('CONTOUR_SHADOWS', defaultValue: true);
  static final bool _diagnostics =
      bool.tryParse(_route['diagnostics'] ?? '') ?? const bool.fromEnvironment('CONTOUR_DIAGNOSTICS');
  static final String _workload =
      _route['workload'] ?? const String.fromEnvironment('CONTOUR_WORKLOAD', defaultValue: 'combined');
  static final int _count =
      int.tryParse(_route['count'] ?? '') ?? const int.fromEnvironment('CONTOUR_COUNT', defaultValue: 20);
  static final int _cadenceMs =
      int.tryParse(_route['updateMs'] ?? '') ?? const int.fromEnvironment('CONTOUR_UPDATE_MS', defaultValue: 1500);
  static final int _coldFrames =
      int.tryParse(_route['coldFrames'] ?? '') ?? const int.fromEnvironment('CONTOUR_COLD_FRAMES', defaultValue: 120);
  static final int _steadyFrames =
      int.tryParse(_route['steadyFrames'] ?? '') ??
      const int.fromEnvironment('CONTOUR_STEADY_FRAMES', defaultValue: 300);
  static final int _delayMs = int.tryParse(_route['delayMs'] ?? '') ?? const int.fromEnvironment('CONTOUR_DELAY_MS');
  static final String? _cpuMask = _route['cpumask'];
  final ContourBenchmarkProbe _probe = ContourBenchmarkProbe();
  Map<String, Object?>? _affinityAtStart;
  late final AnimationController _controller;
  late List<GlobalKey> _keys;
  ContourBenchmarkPresentationTracker? _initialPresentation;
  ContourBenchmarkPresentationTracker? _warmPresentation;
  Map<String, Object?>? _implementationBeforeRemount;
  final Stopwatch _elapsed = Stopwatch();
  final List<ui.FrameTiming> _cold = [];
  final List<ui.FrameTiming> _steady = [];
  final List<int> _initialReadyUs = [];
  final List<int> _refreshReadyUs = [];
  final Set<int> _initialReady = {};
  Timer? _pollTimer;
  Timer? _startTimer;
  bool _started = false;
  int _generation = 0;
  int? _refreshStartedUs;
  int _refreshes = 0;
  int _supersededRefreshes = 0;
  int? _allReadyUs;
  bool _reported = false;
  bool _layoutError = false;
  Size? _viewport;

  bool get _changesContent => _updates || _workload == 'content';

  @override
  void initState() {
    super.initState();
    _contourColor = ContourBenchmarkColor.parse(_colorHex);
    if ((_warmReuse && (!_diagnostics || !_enabled || _workload != 'static' || _updates)) ||
        _delayMs < 0 ||
        _count < 1 ||
        (_unique && !_large && _count > _uniqueIcons.length * 2) ||
        _cadenceMs < 1 ||
        _coldFrames < 1 ||
        _steadyFrames < 1 ||
        !const ['static', 'translation', 'rotation', 'combined', 'amount', 'content'].contains(_workload)) {
      throw StateError('Invalid Contour benchmark configuration.');
    }
    if (_cpuMask case final String mask) {
      debugPrint(
        'CONTOUR_BENCHMARK_AFFINITY ${jsonEncode(ContourBenchmarkCpuAffinity.apply(mask, onThread: (thread) => _logAffinityThread('init', thread)))}',
      );
    }
    _keys = List.generate(_large ? 1 : _count, (_) => GlobalKey());
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..addListener(_tick);
    _startTimer = Timer(Duration(milliseconds: _delayMs), _start);
  }

  void _start() {
    if (_cpuMask case final String mask) {
      _affinityAtStart = ContourBenchmarkCpuAffinity.apply(
        mask,
        onThread: (thread) => _logAffinityThread('start', thread),
      );
    }
    if (_enabled && _diagnostics) {
      _initialPresentation = ContourBenchmarkPresentationTracker(
        instances: _keys.length,
        startTimelineUs: developer.Timeline.now,
      );
      SchedulerBinding.instance.addPostFrameCallback(_observePresentation);
    }
    _elapsed.start();
    SchedulerBinding.instance.addTimingsCallback(_record);
    setState(() => _started = true);
    _controller.repeat();
    debugPrint(
      'CONTOUR_BENCHMARK_START ${jsonEncode({'delay_ms': _delayMs, 'workload': _workload, 'enabled': _enabled})}',
    );
    if (_enabled && _diagnostics) {
      _pollTimer = Timer.periodic(const Duration(milliseconds: 20), (_) => _pollReadiness());
    }
  }

  void _logAffinityThread(String phase, Map<String, Object?> thread) {
    debugPrintSynchronously('CONTOUR_BENCHMARK_AFFINITY_THREAD ${jsonEncode({'phase': phase, ...thread})}');
  }

  void _tick() {
    final next = _elapsed.elapsedMilliseconds ~/ _cadenceMs;
    if (_changesContent && next != _generation) {
      if (_refreshStartedUs != null) _supersededRefreshes++;
      _refreshStartedUs = _elapsed.elapsedMicroseconds;
      _refreshes++;
      setState(() => _generation = next);
    }
  }

  Map<String, Object?> _properties(GlobalKey key) {
    final render = key.currentContext?.findRenderObject();
    if (render == null) return const {};
    return _probe.properties(render);
  }

  void _pollReadiness() {
    if (_reported) return;
    final now = _elapsed.elapsedMicroseconds;
    var ready = 0;
    for (var index = 0; index < _keys.length; index++) {
      final properties = _properties(_keys[index]);
      // A usable contour path counts as ready even if optional background
      // cache preparation is still running in a particular implementation.
      if (properties['contourReady'] == true) {
        ready++;
        if (_initialReady.add(index)) _initialReadyUs.add(now);
      }
    }
    if (ready != _keys.length) return;
    _allReadyUs ??= now;
    if (_refreshStartedUs case final int started) {
      _refreshReadyUs.add(now - started);
      _refreshStartedUs = null;
    }
    if (!_changesContent) _pollTimer?.cancel();
  }

  void _observePresentation(Duration _) {
    if (!mounted || _reported) return;
    final samples = [for (final key in _keys) _properties(key)];
    final active = (_warmPresentation ?? _initialPresentation!)
      ..observe(frameNumber: WidgetsBinding.instance.platformDispatcher.frameData.frameNumber, samples: samples);
    if (_warmReuse &&
        _warmPresentation == null &&
        active.allPaired &&
        _allReadyUs != null &&
        samples.every((sample) => sample['generating'] == false)) {
      _implementationBeforeRemount = _probe.summarize(samples);
      setState(() {
        _keys = List.generate(_keys.length, (_) => GlobalKey());
        _warmPresentation = ContourBenchmarkPresentationTracker(
          instances: _keys.length,
          startTimelineUs: developer.Timeline.now,
        );
      });
    }
    if (!active.allPaired || (_warmReuse && _warmPresentation?.allPaired != true)) {
      SchedulerBinding.instance.addPostFrameCallback(_observePresentation);
    }
  }

  void _record(List<ui.FrameTiming> timings) {
    if (_reported || _layoutError) return;
    if (_initialPresentation case final tracker?) {
      final received = developer.Timeline.now;
      tracker.recordTimings(timings, receivedTimelineUs: received);
      _warmPresentation?.recordTimings(timings, receivedTimelineUs: received);
    }
    for (final timing in timings) {
      if (_cold.length < _coldFrames) {
        _cold.add(timing);
      } else if (_steady.length < _steadyFrames) {
        _steady.add(timing);
      }
    }
    if (_steady.length < _steadyFrames) return;
    _reported = true;
    _pollTimer?.cancel();
    _controller.stop();
    final rate = View.of(context).display.refreshRate;
    final budget = 1000000 / (rate > 0 ? rate : 60);
    final result = jsonEncode({
      'schema': 2,
      'generic': _generic,
      'implementation_at_end': _probe.summarize([for (final key in _keys) _properties(key)]),
      if (_cpuMask != null) 'affinity_at_start': _affinityAtStart,
      if (_cpuMask != null)
        'affinity_at_end': ContourBenchmarkCpuAffinity.inspect(
          _cpuMask!,
          onThread: (thread) => _logAffinityThread('end', thread),
        ),
      'delay_ms': _delayMs,
      'enabled': _enabled,
      'workload': _workload,
      'updates': _changesContent,
      'update_cadence_ms': _cadenceMs,
      'refreshes_requested': _refreshes,
      'large': _large,
      'unique': _unique,
      'contour_color': _colorHex.toLowerCase(),
      'shadows': _shadows,
      'instances': _keys.length,
      'mode': kProfileMode ? 'profile' : (kReleaseMode ? 'release' : 'debug'),
      'viewport': {'width': _viewport?.width, 'height': _viewport?.height},
      'device_pixel_ratio': View.of(context).devicePixelRatio,
      'display_refresh_hz': rate,
      'frame_budget_us': budget,
      'elapsed_wall_us': _elapsed.elapsedMicroseconds,
      'cold': _summarize(_cold, budget),
      'steady': _summarize(_steady, budget),
      'diagnostics_enabled': _diagnostics,
      if (_initialPresentation case final tracker?)
        'presentation_readiness': {
          'probe_version': 1,
          'warm_reuse_requested': _warmReuse,
          'warm_reuse_lifetime': _warmReuse ? 'excluded_offstage_transparent_owner' : null,
          'warm_reuse_phase': !_warmReuse
              ? 'not_requested'
              : _warmPresentation == null
              ? 'not_started'
              : 'started',
          'warm_reuse_requested_after_initial_us': _warmPresentation == null
              ? null
              : _warmPresentation!.startTimelineUs - tracker.startTimelineUs,
          'initial': tracker.summarize(),
          'warm_reuse': _warmPresentation?.summarize(),
          'implementation_before_remount': _implementationBeforeRemount,
        },
      if (_diagnostics && _enabled)
        'shape_readiness': {
          'poll_resolution_us': 20000,
          'ready_definition': 'first_contour_path',
          'probe_version': 2,
          'initial_ready_instances': _initialReady.length,
          'initial_instance_p50_us': _percentile(_initialReadyUs, .5),
          'initial_instance_p99_us': _percentile(_initialReadyUs, .99),
          'initial_all_ready_us': _allReadyUs,
          'refreshes_completed': _refreshReadyUs.length,
          'refreshes_superseded': _supersededRefreshes,
          'refresh_all_ready_p99_us': _percentile(_refreshReadyUs, .99),
          'captures_at_end': _keys.fold<int>(0, (sum, key) => sum + ((_properties(key)['captureCount'] as int?) ?? 0)),
        },
    });
    unawaited(_printResult(result));
  }

  Future<void> _printResult(String result) async {
    const chunkLength = 600;
    final chunks = (result.length + chunkLength - 1) ~/ chunkLength;
    debugPrintSynchronously('CONTOUR_BENCHMARK_BEGIN ${jsonEncode({'chunks': chunks, 'characters': result.length})}');
    for (var index = 0; index < chunks; index++) {
      final end = math.min((index + 1) * chunkLength, result.length);
      debugPrintSynchronously(
        'CONTOUR_BENCHMARK_CHUNK ${index + 1}/$chunks ${result.substring(index * chunkLength, end)}',
      );
      // Bound the post-run log burst so Android's logging transport can drain
      // large diagnostic tables without dropping later chunks or the END marker.
      if (index + 1 < chunks) await Future<void>.delayed(const Duration(milliseconds: 8));
    }
    debugPrintSynchronously('CONTOUR_BENCHMARK_END');
  }

  int? _percentile(List<int> values, double fraction) {
    if (values.isEmpty) return null;
    final sorted = values.toList()..sort();
    return sorted[(sorted.length * fraction).ceil() - 1];
  }

  Map<String, Object?> _summarize(List<ui.FrameTiming> frames, double budget) {
    final build = frames.map((frame) => frame.buildDuration.inMicroseconds).toList();
    final raster = frames.map((frame) => frame.rasterDuration.inMicroseconds).toList();
    final latency = frames.map((frame) => frame.totalSpan.inMicroseconds).toList();
    final gaps = <int>[];
    var missedSlots = 0;
    for (var index = 1; index < frames.length; index++) {
      final gap =
          frames[index].timestampInMicroseconds(ui.FramePhase.vsyncStart) -
          frames[index - 1].timestampInMicroseconds(ui.FramePhase.vsyncStart);
      gaps.add(gap);
      missedSlots += math.max(0, (gap / budget).round() - 1);
    }
    final stageOverBudget = frames
        .where((frame) => frame.buildDuration.inMicroseconds > budget || frame.rasterDuration.inMicroseconds > budget)
        .length;
    return {
      'frames': frames.length,
      'vsync_span_us':
          frames.last.timestampInMicroseconds(ui.FramePhase.vsyncStart) -
          frames.first.timestampInMicroseconds(ui.FramePhase.vsyncStart),
      'build_p50_us': _percentile(build, .5),
      'build_p90_us': _percentile(build, .9),
      'build_p99_us': _percentile(build, .99),
      'build_max_us': build.reduce(math.max),
      'raster_p50_us': _percentile(raster, .5),
      'raster_p90_us': _percentile(raster, .9),
      'raster_p99_us': _percentile(raster, .99),
      'raster_max_us': raster.reduce(math.max),
      'total_span_p99_us': _percentile(latency, .99),
      'vsync_gap_p99_us': _percentile(gaps, .99),
      'stage_over_budget_frames': stageOverBudget,
      'stage_over_budget_percent': 100 * stageOverBudget / frames.length,
      'estimated_missed_vsync_slots': missedSlots,
    };
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_record);
    _pollTimer?.cancel();
    _startTimer?.cancel();
    _controller.dispose();
    _probe.dispose();
    super.dispose();
  }

  Widget _content(int index) => _generic
      ? ContourBenchmarkGenericArtwork(variant: (_unique ? index : index % 2) + _generation * 2)
      : _large
      ? Text(_generation.isEven ? 'Armando?' : 'Contorno!', style: const TextStyle(fontSize: 56, color: Colors.blue))
      : index.isEven
      ? Text(
          _unique ? '${_generation.isEven ? 'T' : 'U'}${index ~/ 2}' : (_generation.isEven ? 'Ab' : 'Oo'),
          style: const TextStyle(fontSize: 20, color: Colors.blue),
        )
      : Icon(
          _unique
              ? _uniqueIcons[(_generation + index ~/ 2) % _uniqueIcons.length]
              : (_generation.isEven ? Icons.favorite : Icons.star),
          size: 24,
          color: Colors.red,
        );

  Widget _tile(int index, double amount) {
    final content = _content(index);
    return SizedBox(
      width: _large ? 320 : 48,
      height: _large ? 100 : 48,
      child: Center(
        child: _enabled
            ? Contour(
                key: _keys[index],
                color: _contourColor,
                amount: amount,
                shadows: _shadows
                    ? const [Shadow(color: Color(0x33000000), offset: Offset(0, 3), blurRadius: 6)]
                    : const [],
                child: content,
              )
            : content,
      ),
    );
  }

  Widget _composition(double amount) =>
      Wrap(spacing: 2, runSpacing: 2, children: List.generate(_keys.length, (index) => _tile(index, amount)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEAEAEA),
    body: _warmReuse
        ? Stack(
            children: [
              const Offstage(
                child: Contour(color: Color(0x00000000), child: SizedBox.shrink()),
              ),
              _benchmarkBody,
            ],
          )
        : _benchmarkBody,
  );

  Widget get _benchmarkBody => !_started
      ? const SizedBox.shrink()
      : SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewport = constraints.biggest;
                final columns = _large ? 1 : ((constraints.maxWidth + 2) / 50).floor();
                final rows = columns > 0 ? (_keys.length / columns).ceil() : _keys.length;
                final requiredHeight = _large ? 100.0 : rows * 50.0 - 2;
                if (columns == 0 || requiredHeight > constraints.maxHeight || (_large && constraints.maxWidth < 320)) {
                  if (!_layoutError) {
                    _layoutError = true;
                    debugPrint(
                      'CONTOUR_BENCHMARK_ERROR workload does not fit viewport; reduce count or use a larger viewport.',
                    );
                  }
                  return const Center(child: Text('Workload does not fit. See benchmark log.'));
                }
                return Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    child: _workload == 'amount' ? null : _composition(4),
                    builder: (context, child) {
                      final wave = math.sin(_controller.value * math.pi * 2);
                      final content = child ?? _composition(4 + wave * 3);
                      final translation = _workload == 'translation' || _workload == 'combined' ? wave * 12 : 0.0;
                      final rotation = _workload == 'rotation' || _workload == 'combined' ? wave * .04 : 0.0;
                      return Transform.translate(
                        offset: Offset(translation, 0),
                        child: Transform.rotate(angle: rotation, child: content),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
}
