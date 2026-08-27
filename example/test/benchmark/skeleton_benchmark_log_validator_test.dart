import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/skeleton/skeleton_benchmark_log_validator.dart';

void main() {
  String buildLog({
    bool animationsDisabled = false,
    int probePaints = 0,
    int transientCallbacks = 1,
    bool? structuralInvariantsPassed,
  }) {
    const runId = 'skeleton-test-run';
    const frames = 60;
    const budget = 16666;
    final records = <Map<String, Object?>>[
      <String, Object?>{
        'path': 'environment',
        'run_id': runId,
        'mode': 'profile',
        'renderer': 'skia-opengles',
        'effect': 'shimmer',
        'topology': 'single',
        'card_count': 16,
        'refresh_rate_hz': 60.0,
        'frame_budget_us': budget,
        'logical_size': <String, double>{'width': 360, 'height': 640},
        'physical_size': <String, double>{'width': 720, 'height': 1280},
        'device_pixel_ratio': 2.0,
        'animations_disabled': animationsDisabled,
        'warmup_frames_per_trial': 30,
        'steady_trials': 2,
        'steady_frames_per_trial': frames,
        'maximum_trial_attempts': 3,
      },
    ];
    final measuredStructuralPass = probePaints == 0 && transientCallbacks == 1;
    final structuralPass = structuralInvariantsPassed ?? measuredStructuralPass;
    for (var trial = 1; trial <= 2; trial += 1) {
      records.add(<String, Object?>{
        'path': 'steady.trial_$trial',
        'run_id': runId,
        'effect': 'shimmer',
        'topology': 'single',
        'phase': 'steady',
        'trial': trial,
        'attempt': 1,
        'retried': false,
        'valid': true,
        'gate': true,
        'frames': frames,
        'probe_paints': probePaints,
        'transient_callbacks': transientCallbacks,
        'build': _statistics,
        'raster': _statistics,
        'total_span': _statistics,
        'vsync_overhead': _statistics,
        'build_over_budget': 0,
        'raster_over_budget': 0,
        'total_span_over_budget': 0,
        'any_over_budget': 0,
        'longest_consecutive_misses': 0,
        'work_p99_within_budget': true,
        'structural_invariants_passed': structuralPass,
        'frame_budget_us': budget,
      });
    }
    records.add(<String, Object?>{
      'path': 'acceptance',
      'run_id': runId,
      'passed': true,
      'enforced': true,
      'failed_steady_paths': <String>[],
      'steady_trials': 2,
      'steady_frames_per_trial': frames,
      'maximum_trial_attempts': 3,
      'invalid_trial_attempts': 0,
      'retried_trials': 0,
    });
    return records
        .map(
          (record) => 'flutter: SKELETON_BENCHMARK ${jsonEncode(record)}',
        )
        .join('\n');
  }

  SkeletonBenchmarkLogValidator validator() {
    return SkeletonBenchmarkLogValidator(
      expectedRunId: 'skeleton-test-run',
      expectedRenderer: 'skia-opengles',
      expectedEffect: 'shimmer',
      expectedTopology: 'single',
      expectedCardCount: 16,
      expectedWarmupFrames: 30,
      expectedFramesPerTrial: 60,
      requireBudgetPass: true,
      requireEnforcedBudget: true,
    );
  }

  group('SkeletonBenchmarkLogValidator', () {
    test('when a complete benchmark log passes, it should accept it', () {
      final validation = validator().validate(buildLog());

      expect(validation.passed, isTrue);
    });

    test(
      'when platform animations are disabled, it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(animationsDisabled: true),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when descendants repaint during steady animation, '
      'it should reject the log',
      () {
        final validation = validator().validate(buildLog(probePaints: 1));

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when Skeletons use more than one animation callback, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(transientCallbacks: 16),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when the structural result disagrees with its measurements, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(structuralInvariantsPassed: false),
        );

        expect(validation.passed, isFalse);
      },
    );
  });
}

const Map<String, num> _statistics = <String, num>{
  'p50_us': 1000,
  'p90_us': 2000,
  'p99_us': 3000,
  'max_us': 4000,
  'mean_us': 1500,
};
