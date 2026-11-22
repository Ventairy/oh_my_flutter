import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../contour/contour_benchmark_cpu_affinity.dart';
import 'motion_blur_benchmark_probe.dart';

const _scenarioNames = String.fromEnvironment(
  'MOTION_BLUR_SCENARIOS',
  defaultValue: 'widget,text,particles,blurred-source',
);
const _sigmaValues = String.fromEnvironment('MOTION_BLUR_SIGMAS', defaultValue: '0,4');
const _repetitions = int.fromEnvironment('MOTION_BLUR_REPETITIONS', defaultValue: 8);
const _defaultCpuMask = String.fromEnvironment('MOTION_BLUR_CPU_MASK');
const _defaultPinWarmReplays = bool.fromEnvironment('MOTION_BLUR_PIN_WARM_REPLAYS');
const _defaultLabel = String.fromEnvironment('MOTION_BLUR_LABEL', defaultValue: 'unrestricted');
const _requireNative = bool.fromEnvironment('MOTION_BLUR_REQUIRE_NATIVE', defaultValue: true);
const _traceCold = bool.fromEnvironment('MOTION_BLUR_TRACE_COLD');
const _traceReplay = bool.fromEnvironment('MOTION_BLUR_TRACE_REPLAY');
const _traceStreams = ['Dart', 'Embedder', 'GC', 'Compiler'];
const _effectDuration = Duration(milliseconds: 300);
const _stagger = Duration(milliseconds: 4);
const _denseText = 'Sphinx of black quartz, judge my vow. 0123456789';
const _clippedText = 'Soft edges in motion. ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789';
const _particlePulses = {'particles', 'particles-large', 'particles-tall'};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('when motion uses blur, it should report frame timing on the device', (tester) async {
    final query = Uri.tryParse(PlatformDispatcher.instance.defaultRouteName)?.queryParameters;
    final label = query?['label'] ?? _defaultLabel;
    final cpuMask = query?['cpumask'] ?? _defaultCpuMask;
    final warmPin = query?['pinWarmReplays'];
    final pinWarmReplays = cpuMask.isNotEmpty && (warmPin == null ? _defaultPinWarmReplays : warmPin == '1');
    final replayAffinityChecks = pinWarmReplays ? <String, List<Map<String, Object?>>>{} : null;
    final results = <String, Object>{};
    final probe = MotionBlurBenchmarkProbe();
    addTearDown(probe.dispose);
    final environment = <String, Object?>{
      'label': label,
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'refreshHz': tester.view.display.refreshRate,
      'physicalWidth': tester.view.physicalSize.width,
      'physicalHeight': tester.view.physicalSize.height,
      'devicePixelRatio': tester.view.devicePixelRatio,
      'repetitions': _repetitions,
      'timingSource': 'Flutter FrameTiming',
      'cadenceSource': 'Gaps between Flutter vsyncStart timestamps in each playback window',
      if (pinWarmReplays) 'cpuAffinityScope': 'warm replays',
      'replayAffinityChecks': ?replayAffinityChecks,
    };
    binding.reportData = {'environment': environment, 'motionBlur': results};
    if (cpuMask.isNotEmpty && !pinWarmReplays) {
      final affinity = ContourBenchmarkCpuAffinity.apply(cpuMask, onThread: (_) {});
      environment['affinityAtStart'] = affinity;
      expect(affinity['all_threads_restricted'], isTrue, reason: 'Could not apply CPU mask $cpuMask.');
    }
    final scenarios = (query?['scenarios'] ?? _scenarioNames).split(',');
    final sigmas = (query?['sigmas'] ?? _sigmaValues).split(',').map(double.parse);
    final scheduler = SchedulerBinding.instance;
    final refreshHz = tester.view.display.refreshRate;
    final frameBudgetMicros = Duration.microsecondsPerSecond / (refreshHz > 0 ? refreshHz : 60);
    for (final scenario in scenarios) {
      for (final sigma in sigmas) {
        final frames = <FrameTiming>[];
        final windows = <({int start, int end})>[];
        final activeWindows = <({int start, int end})>[];
        final replayStartDelays = <double>[];
        final controller = MotionController();
        final requestClock = Stopwatch();
        int? startedAt;
        int? completedAt;
        double? startDelay;
        final child = _scene(
          scenario,
          sigma,
          controller,
          onStart: () {
            startedAt ??= scheduler.currentSystemFrameTimeStamp.inMicroseconds;
            startDelay ??= requestClock.elapsedMicroseconds / 1000;
          },
          onEnd: () {
            completedAt ??= scheduler.currentSystemFrameTimeStamp.inMicroseconds;
          },
        );
        Future<void> play() async {
          startedAt = null;
          completedAt = null;
          startDelay = null;
          requestClock
            ..reset()
            ..start();
          controller.play();
          // Let preparation schedule its paint before the test requests a frame.
          await Future<void>.value();
          await tester.pump();
        }

        final isParticles = _particlePulses.contains(scenario) || scenario == 'blurred-source';
        final settleTime =
            _effectDuration +
            _stagger *
                (switch (scenario) {
                  'text-dense' => _denseText.length,
                  'text-clipped' => _clippedText.length,
                  'text' || 'text-hidden' => 20,
                  _ => 0,
                }) +
            (isParticles ? const Duration(milliseconds: 180) : const Duration(milliseconds: 100));
        final coldFrames = <FrameTiming>[];
        final recordColdTimings = coldFrames.addAll;
        await tester.pump();
        final beforeMount = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
        late final int mountedAt;
        late final int firstPlayEnd;
        late final Size size;
        var particleOutput = 'none';
        scheduler.addTimingsCallback(recordColdTimings);
        Future<void> runColdPlayback() async {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Center(child: child),
              ),
            ),
          );
          mountedAt = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
          size = tester.getSize(find.byWidget(child));
          await play();
          if (isParticles) {
            final texture = find.byType(Texture);
            final customPaint = find.descendant(of: find.byWidget(child), matching: find.byType(CustomPaint));
            for (var i = 0; i < 90 && texture.evaluate().isEmpty && customPaint.evaluate().isEmpty; i++) {
              await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
              await tester.pump();
            }
            if (scenario == 'blurred-source' && sigma > 0) {
              expect(customPaint, findsOneWidget);
            } else if (_requireNative) {
              expect(texture, findsOneWidget);
            } else {
              expect(texture.evaluate().isNotEmpty || customPaint.evaluate().isNotEmpty, isTrue);
            }
            particleOutput = texture.evaluate().isEmpty ? 'flutter-atlas' : 'native-texture';
          }
          await tester.runAsync(() => Future<void>.delayed(settleTime));
          firstPlayEnd = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
        }

        final tracksGlyphShader = scenario.startsWith('text') && sigma > 0;
        bool? glyphShaderWarmedBeforeReplay;
        try {
          if (_traceCold) {
            await binding.traceAction(
              runColdPlayback,
              streams: _traceStreams,
              reportKey: 'coldTimeline/$scenario/$sigma',
            );
          } else {
            await runColdPlayback();
          }
          final framePolicy = binding.framePolicy;
          try {
            if (tracksGlyphShader &&
                completedAt != null &&
                Platform.isAndroid &&
                !ImageFilter.isShaderFilterSupported) {
              // LiveTest injects empty frames even after playback stops.
              // Pause their Flutter callbacks during the shader's idle window.
              binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
            }
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
          } finally {
            binding.framePolicy = framePolicy;
          }
          if (tracksGlyphShader) {
            glyphShaderWarmedBeforeReplay = probe.glyphShaderWarmed(tester.renderObject(find.byType(TextMotion)));
          }
        } finally {
          scheduler.removeTimingsCallback(recordColdTimings);
        }
        final coldCompletion = completedAt;
        final coldWindow = (start: mountedAt, end: coldCompletion ?? firstPlayEnd);
        final coldStart = startedAt;
        final coldStartDelay = startDelay;
        final affinityChecks = replayAffinityChecks?.putIfAbsent('$scenario/$sigma', () => []);
        void checkReplayAffinity(String checkpoint, {bool pin = false}) {
          if (affinityChecks == null) return;
          final threads = <Map<String, Object?>>[];
          final affinity = pin
              ? ContourBenchmarkCpuAffinity.apply(cpuMask, onThread: threads.add)
              : ContourBenchmarkCpuAffinity.inspect(cpuMask, onThread: threads.add);
          affinityChecks.add({'checkpoint': checkpoint, ...affinity, 'threads': threads});
          expect(
            affinity['all_threads_restricted'],
            isTrue,
            reason: '$scenario/$sigma exceeded CPU mask at $checkpoint.',
          );
        }

        checkReplayAffinity('before replay series', pin: true);
        final recordTimings = frames.addAll;
        scheduler.addTimingsCallback(recordTimings);
        Future<void> replay(int number) async {
          await tester.pump();
          if (pinWarmReplays) checkReplayAffinity('before replay $number');
          final start = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
          await play();
          await tester.runAsync(() => Future<void>.delayed(settleTime));
          if (completedAt == null) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
          }
          final end = completedAt;
          final activeStart = startedAt;
          final delay = startDelay;
          expect(end, isNotNull, reason: '$scenario/$sigma replay did not reach its completion callback.');
          expect(delay, isNotNull, reason: '$scenario/$sigma replay did not reach its start callback.');
          windows.add((start: start, end: end!));
          activeWindows.add((start: activeStart!, end: end));
          replayStartDelays.add(delay!);
          if (pinWarmReplays) checkReplayAffinity('after replay $number');
        }

        try {
          if (_traceReplay) {
            final traceEvents = <Map<String, Object?>>[];
            int? traceStart;
            int? traceEnd;
            // A long Skia trace can overwrite the first replay in the VM's ring buffer.
            for (var number = 1; number <= _repetitions; number++) {
              const startMark = 'MotionBlurBenchmark::ReplayTraceStart';
              const endMark = 'MotionBlurBenchmark::ReplayTraceEnd';
              final trace = await binding.traceTimeline(() async {
                developer.Timeline.instantSync(startMark, arguments: {'replay': number});
                await replay(number);
                developer.Timeline.instantSync(endMark, arguments: {'replay': number});
              }, streams: _traceStreams);
              final events = trace.traceEvents!;
              final markers = <String, int>{};
              for (final event in events) {
                if (event.json case {'name': final String name, 'ts': final int timestamp}
                    when name == startMark || name == endMark) {
                  markers[name] = timestamp;
                }
              }
              expect(
                markers.keys,
                unorderedEquals([startMark, endMark]),
                reason: '$scenario/$sigma replay $number did not fit in the VM trace buffer.',
              );
              traceEvents.addAll(events.map((event) => event.toJson()));
              traceStart ??= markers[startMark];
              traceEnd = markers[endMark];
            }
            binding.reportData!['replayTimeline/$scenario/$sigma'] = {
              'type': 'Timeline',
              'traceEvents': traceEvents,
              'timeOriginMicros': traceStart ?? -1,
              'timeExtentMicros': traceEnd == null ? -1 : traceEnd - traceStart!,
            };
          } else {
            for (var number = 1; number <= _repetitions; number++) {
              await replay(number);
            }
          }
          // Profile mode delivers FrameTiming batches at one-second intervals.
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
        } finally {
          scheduler.removeTimingsCallback(recordTimings);
        }
        final steady = _summarize(frames, windows, frameBudgetMicros);
        expect(steady['frames'], greaterThan(0), reason: '$scenario/$sigma produced no in-window frame timings.');
        results['$scenario/$sigma'] = {
          'width': size.width,
          'height': size.height,
          'particleOutput': particleOutput,
          'glyphShaderWarmedBeforeReplay': ?glyphShaderWarmedBeforeReplay,
          'playbackWindowsUs': [
            for (final window in windows) [window.start, window.end],
          ],
          'replayActiveWindowsUs': [
            for (final window in activeWindows) [window.start, window.end],
          ],
          ...steady,
          'coldMount': _summarize(coldFrames, [(start: beforeMount, end: mountedAt)], frameBudgetMicros),
          'coldFirstPlay': _summarize(coldFrames, [(start: mountedAt, end: firstPlayEnd)], frameBudgetMicros),
          'coldPlaybackWindowUs': [coldWindow.start, coldWindow.end],
          'coldAnimated': _summarize(coldFrames, [coldWindow], frameBudgetMicros),
          'coldFramePhasesUs': _framePhases(coldFrames, [coldWindow]),
          'coldStartedAtUs': ?coldStart,
          'coldCompletedAtUs': ?coldCompletion,
          'coldStartDelayMs': ?coldStartDelay,
          'replayStartDelaysMs': replayStartDelays,
          'replayFramePhasesUs': _framePhases(frames, windows),
        };
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    if (cpuMask.isNotEmpty && !pinWarmReplays) {
      final affinity = ContourBenchmarkCpuAffinity.inspect(cpuMask, onThread: (_) {});
      environment['affinityAtEnd'] = affinity;
      expect(affinity['all_threads_restricted'], isTrue, reason: 'CPU affinity changed during measurement.');
    }
  });
}

List<List<int>> _framePhases(List<FrameTiming> frames, List<({int start, int end})> windows) => [
  for (final frame in frames)
    if (windows.any((window) {
      final vsync = frame.timestampInMicroseconds(FramePhase.vsyncStart);
      return vsync > window.start && vsync <= window.end;
    }))
      [
        frame.timestampInMicroseconds(FramePhase.vsyncStart),
        frame.timestampInMicroseconds(FramePhase.buildStart),
        frame.timestampInMicroseconds(FramePhase.buildFinish),
        frame.timestampInMicroseconds(FramePhase.rasterStart),
        frame.timestampInMicroseconds(FramePhase.rasterFinish),
      ],
];

Map<String, num> _summarize(List<FrameTiming> frames, List<({int start, int end})> windows, double frameBudgetMicros) {
  final retained = <FrameTiming>[];
  final intervals = <int>[];
  var missedVsyncs = 0;
  for (final window in windows) {
    int? previous;
    for (final frame in frames) {
      final start = frame.timestampInMicroseconds(FramePhase.vsyncStart);
      if (start <= window.start || start > window.end) continue;
      retained.add(frame);
      if (previous != null) {
        final interval = start - previous;
        intervals.add(interval);
        final gap = (interval / frameBudgetMicros).round() - 1;
        if (gap > 0) missedVsyncs += gap;
      }
      previous = start;
    }
  }
  if (retained.isEmpty) return {'frames': 0};
  final ui = retained.map((frame) => frame.buildDuration.inMicroseconds).toList()..sort();
  final raster = retained.map((frame) => frame.rasterDuration.inMicroseconds).toList()..sort();
  final total = retained.map((frame) => frame.totalSpan.inMicroseconds).toList()..sort();
  intervals.sort();
  return {
    'frames': retained.length,
    'uiP50Ms': _percentile(ui, 0.5),
    'uiP95Ms': _percentile(ui, 0.95),
    'uiP99Ms': _percentile(ui, 0.99),
    'rasterP50Ms': _percentile(raster, 0.5),
    'rasterP95Ms': _percentile(raster, 0.95),
    'rasterP99Ms': _percentile(raster, 0.99),
    'totalP95Ms': _percentile(total, 0.95),
    'totalP99Ms': _percentile(total, 0.99),
    'maxRasterMs': raster.last / 1000,
    'maxUiMs': ui.last / 1000,
    'framesOver16.7Ms': retained.where((frame) => _exceedsStage(frame, 16700)).length,
    'framesOverDisplayBudget': retained.where((frame) => _exceedsStage(frame, frameBudgetMicros)).length,
    'estimatedMissedVsyncSlots': missedVsyncs,
    if (intervals.isNotEmpty) ...{
      'vsyncIntervalP50Ms': _percentile(intervals, 0.5),
      'vsyncIntervalP95Ms': _percentile(intervals, 0.95),
      'vsyncIntervalP99Ms': _percentile(intervals, 0.99),
      'maxVsyncIntervalMs': intervals.last / 1000,
    },
  };
}

double _percentile(List<int> sortedMicros, double percentile) =>
    sortedMicros[(sortedMicros.length * percentile).ceil() - 1] / 1000;

bool _exceedsStage(FrameTiming frame, num budgetMicros) =>
    frame.buildDuration.inMicroseconds > budgetMicros || frame.rasterDuration.inMicroseconds > budgetMicros;

Widget _scene(
  String scenario,
  double sigma,
  MotionController controller, {
  required VoidCallback onStart,
  required VoidCallback onEnd,
}) {
  final effect = _ProfileEffect(sigma, scenario: scenario, onStart: onStart, onEnd: onEnd);
  switch (scenario) {
    case 'text':
    case 'text-hidden':
    case 'text-dense':
    case 'text-clipped':
      final clipped = scenario == 'text-clipped';
      final text = TextMotion(
        startup: MotionStartup.hold,
        controller: controller,
        stagger: _stagger,
        effect: effect,
        child: Text(
          switch (scenario) {
            'text-dense' => _denseText,
            'text-clipped' => _clippedText,
            _ => 'Soft edges in motion',
          },
          maxLines: clipped ? 1 : null,
          overflow: clipped ? TextOverflow.ellipsis : null,
          style: const TextStyle(fontSize: 28, color: Color(0xFF193457)),
        ),
      );
      return clipped ? SizedBox(width: 300, child: text) : text;
    case 'widget':
    case 'widget-large':
    case 'particles':
    case 'particles-large':
    case 'particles-tall':
    case 'blurred-source':
      final size = switch (scenario) {
        'widget-large' || 'particles-large' => const Size(320, 320),
        'particles-tall' => const Size(344, 480),
        _ => const Size(240, 100),
      };
      return Motion(
        startup: MotionStartup.hold,
        controller: controller,
        effect: effect,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF193457), Color(0xFF599EAC)]),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
      );
    default:
      throw ArgumentError.value(scenario, 'scenario', 'Unknown blur benchmark scenario');
  }
}

class _ProfileEffect extends MotionEffect {
  const new(this.sigma, {required this.scenario, super.onStart, super.onEnd}) : super(duration: _effectDuration);

  final double sigma;
  final String scenario;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    if (scenario == 'blurred-source') {
      transform
        ..blur(sigma)
        ..disintegrate(progress: (progress - 0.12) / 0.88, direction: const Offset(1, -0.6));
    } else if (_particlePulses.contains(scenario)) {
      transform
        ..disintegrate(progress: progress, direction: const Offset(1, -0.6))
        ..blur(sigma * 4 * progress * (1 - progress));
    } else {
      transform
        ..fade(scenario == 'text-hidden' ? progress : 0.35 + 0.65 * progress)
        ..blur(sigma * (1 - progress));
    }
  }
}
