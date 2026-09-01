import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/interactive_swipe_dismiss/interactive_swipe_dismiss_benchmark_log_validator.dart';
import '../../benchmark/interactive_swipe_dismiss/interactive_swipe_dismiss_benchmark_record_buffer.dart';

void main() {
  const expectedRunId = 'interactive-swipe-dismiss-test-run';
  const renderer = 'impeller-vulkan';
  const frames = 4;
  const warmupFrames = 3;
  const frameBudget = 16666;
  const rawTimings = <int>[1000, 1000, 1000, 1000];
  const rawDispatch = <int>[20, 20, 20, 20];
  const timingStatistics = <String, num>{
    'minimum_us': 1000,
    'p50_us': 1000,
    'p90_us': 1000,
    'p99_us': 1000,
    'max_us': 1000,
    'mean_us': 1000,
  };
  const dispatchStatistics = <String, num>{
    'minimum_us': 20,
    'p50_us': 20,
    'p90_us': 20,
    'p99_us': 20,
    'max_us': 20,
    'mean_us': 20,
  };

  List<Map<String, Object>> buildRecords({
    bool corruptBuildStatistics = false,
    int dismissCallbacks = 0,
    String runId = expectedRunId,
    bool requireRetainedPaint = false,
    int? probePaints,
    int rawFrameCount = frames,
    double scrollEnd = 600,
  }) {
    final measuredPaints = probePaints ?? (requireRetainedPaint ? 0 : frames);
    final structuralPass =
        measuredPaints >= 0 &&
        measuredPaints <= frames &&
        (!requireRetainedPaint || measuredPaints == 0) &&
        dismissCallbacks == 0 &&
        scrollEnd == 600 &&
        rawFrameCount == frames;
    final records = <Map<String, Object>>[
      <String, Object>{
        'path': 'environment',
        'run_id': runId,
        'mode': 'profile',
        'platform': 'android',
        'operating_system': 'Android test',
        'renderer': renderer,
        'renderer_source': 'manually verified startup or device logs',
        'scenario': 'cataqui_scrolled_header_free_drag',
        'direction': 'down',
        'free_drag': true,
        'sensitivity': 0.37,
        'dismiss_threshold': 0.25,
        'initial_scroll_offset_px': 600.0,
        'heavy_row_count': 80,
        'gesture_driver': 'synthetic_touch_one_move_per_vsync',
        'refresh_rate_hz': 60.0,
        'frame_budget_us': frameBudget,
        'logical_size': <String, double>{'width': 360, 'height': 800},
        'physical_size': <String, double>{'width': 1080, 'height': 2400},
        'device_pixel_ratio': 3.0,
        'animations_disabled': false,
        'preflight_passed': true,
        'require_retained_paint': requireRetainedPaint,
        'warmup_frames_per_trial': warmupFrames,
        'steady_trials': 2,
        'steady_frames_per_trial': frames,
        'maximum_trial_attempts': 3,
      },
    ];
    final raw = List<int>.filled(rawFrameCount, 1000);
    for (var trial = 1; trial <= 2; trial += 1) {
      final Map<String, num> buildStatistics;
      if (corruptBuildStatistics) {
        buildStatistics = <String, num>{
          ...timingStatistics,
          'p99_us': 2000,
        };
      } else {
        buildStatistics = timingStatistics;
      }
      records.add(<String, Object>{
        'path': 'steady.trial_$trial',
        'run_id': runId,
        'scenario': 'cataqui_scrolled_header_free_drag',
        'phase': 'steady',
        'trial': trial,
        'attempt': 1,
        'retried': false,
        'valid': true,
        'gate': true,
        'frames': frames,
        'pointer_moves': frames,
        'frame_timings_us': <String, Object>{
          'build': raw,
          'raster': rawTimings,
          'total_span': rawTimings,
          'vsync_overhead': rawTimings,
        },
        'build': buildStatistics,
        'raster': timingStatistics,
        'total_span': timingStatistics,
        'vsync_overhead': timingStatistics,
        'dispatch_durations_us': rawDispatch,
        'dispatch': dispatchStatistics,
        'probe_builds': 0,
        'probe_layouts': 0,
        'probe_paints': measuredPaints,
        'retained_paint_required': requireRetainedPaint,
        'scroll_start_px': 600.0,
        'scroll_end_px': scrollEnd,
        'maximum_scroll_drift_px': (scrollEnd - 600).abs(),
        'dismiss_callbacks': dismissCallbacks,
        'maximum_transient_callbacks': 1,
        'maximum_raw_primary_px': 120.0,
        'dismiss_distance_px': 200.0,
        'build_over_budget': 0,
        'raster_over_budget': 0,
        'total_span_over_budget': 0,
        'any_over_budget': 0,
        'longest_consecutive_misses': 0,
        'work_p99_within_budget': true,
        'structural_invariants_passed': structuralPass,
        'frame_budget_us': frameBudget,
      });
    }
    final List<String> failedPaths;
    if (structuralPass) {
      failedPaths = <String>[];
    } else {
      failedPaths = <String>['steady.trial_1', 'steady.trial_2'];
    }
    records.add(<String, Object>{
      'path': 'acceptance',
      'run_id': runId,
      'passed': structuralPass,
      'enforced': true,
      'failed_steady_paths': failedPaths,
      'steady_trials': 2,
      'steady_frames_per_trial': frames,
      'maximum_trial_attempts': 3,
      'invalid_trial_attempts': 0,
      'retried_trials': 0,
    });
    return records;
  }

  String buildLog({
    bool chunkEnvironment = false,
    bool corruptBuildStatistics = false,
    int dismissCallbacks = 0,
    String runId = expectedRunId,
    bool requireRetainedPaint = false,
    int? probePaints,
    int rawFrameCount = frames,
    double scrollEnd = 600,
  }) {
    final records = buildRecords(
      corruptBuildStatistics: corruptBuildStatistics,
      dismissCallbacks: dismissCallbacks,
      runId: runId,
      requireRetainedPaint: requireRetainedPaint,
      probePaints: probePaints,
      rawFrameCount: rawFrameCount,
      scrollEnd: scrollEnd,
    );
    if (!chunkEnvironment) {
      return records
          .map((record) {
            return 'flutter: '
                '${InteractiveSwipeDismissBenchmarkRecordBuffer.recordMarker}'
                '${jsonEncode(record)}';
          })
          .join('\n');
    }
    records.first['padding'] = List<String>.filled(2000, 'x').join();
    final emitted = <String>[];
    final buffer = InteractiveSwipeDismissBenchmarkRecordBuffer(emitted.add);
    records.forEach(buffer.add);
    buffer.flush();
    return emitted.map((line) => 'I/flutter: $line').join('\n');
  }

  InteractiveSwipeDismissBenchmarkLogValidator validator({
    bool requireRetainedPaint = false,
  }) {
    return InteractiveSwipeDismissBenchmarkLogValidator(
      expectedRunId: expectedRunId,
      expectedRenderer: renderer,
      expectedWarmupFrames: warmupFrames,
      expectedFramesPerTrial: frames,
      requireBudgetPass: true,
      requireEnforcedBudget: true,
      requireRetainedPaint: requireRetainedPaint,
    );
  }

  group('InteractiveSwipeDismissBenchmarkLogValidator', () {
    test(
      'when a complete baseline log passes, it should accept diagnostic paints',
      () {
        final validation = validator().validate(buildLog());

        expect(validation.passed, isTrue);
      },
    );

    test(
      'when retained painting is required and zero, it should accept the log',
      () {
        final validation = validator(requireRetainedPaint: true).validate(
          buildLog(requireRetainedPaint: true),
        );

        expect(validation.passed, isTrue);
      },
    );

    test(
      'when retained painting is required but a child paints, '
      'it should reject the log',
      () {
        final validation = validator(requireRetainedPaint: true).validate(
          buildLog(requireRetainedPaint: true, probePaints: 1),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a raw distribution has the wrong frame count, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(rawFrameCount: frames - 1),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when reported statistics disagree with raw timings, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(corruptBuildStatistics: true),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when the scrolled body drifts, it should reject the log',
      () {
        final validation = validator().validate(buildLog(scrollEnd: 601));

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a below-threshold cycle invokes dismissal, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(dismissCallbacks: 1),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when records use a stale run identifier, it should reject the log',
      () {
        final validation = validator().validate(buildLog(runId: 'stale'));

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a valid record is chunked, it should reconstruct and accept it',
      () {
        final validation = validator().validate(
          buildLog(chunkEnvironment: true),
        );

        expect(validation.passed, isTrue);
      },
    );
  });
}
