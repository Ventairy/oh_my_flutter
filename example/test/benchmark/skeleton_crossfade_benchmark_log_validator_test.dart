import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/skeleton/skeleton_crossfade_benchmark_log_validator.dart';

void main() {
  Map<String, num> statistics({int p99 = 3000}) => <String, num>{
    'p50_us': 1000,
    'p90_us': 2000,
    'p99_us': p99,
    'max_us': p99 + 1000,
    'mean_us': 1500,
  };

  List<Map<String, Object?>> records({required String variant}) {
    const runId = 'crossfade-test-run';
    const budget = 16666;
    final source = '$variant-source';
    Map<String, Object?> direction(String path) => <String, Object?>{
      'path': path,
      'run_id': runId,
      'variant': variant,
      'source': source,
      'switches': 20,
      'frames': 320,
      'min_frames_per_switch': 14,
      'max_frames_per_switch': 18,
      'probe_paints': 40,
      'build': statistics(),
      'raster': statistics(),
      'total_span': statistics(),
      'worst_build_per_switch': statistics(),
      'worst_raster_per_switch': statistics(),
      'worst_frame_start_gap_per_switch': statistics(p99: 16000),
      'long_frame_gap_threshold_us': 24999,
      'switches_with_long_frame_start_gap': 0,
      'build_over_budget': 0,
      'raster_over_budget': 0,
      'total_span_over_budget': 0,
      'work_p99_within_budget': true,
      'frame_budget_us': budget,
    };

    return <Map<String, Object?>>[
      <String, Object?>{
        'path': 'environment',
        'run_id': runId,
        'variant': variant,
        'source': source,
        'mode': 'profile',
        'renderer': 'skia-opengles',
        'topology': 'many',
        'effect': 'static',
        'card_count': 12,
        'transition_duration_us': 300000,
        'warmup_switches': 12,
        'measured_switches': 40,
        'refresh_rate_hz': 60.0,
        'frame_budget_us': budget,
        'logical_size': <String, double>{'width': 360, 'height': 592},
        'physical_size': <String, double>{'width': 720, 'height': 1184},
        'device_pixel_ratio': 2.0,
        'animations_disabled': false,
      },
      direction('to_content'),
      direction('to_skeleton'),
      <String, Object?>{
        'path': 'acceptance',
        'run_id': runId,
        'variant': variant,
        'source': source,
        'passed': true,
        'enforced': true,
        'measured_switches': 40,
      },
    ];
  }

  String logFor(List<Map<String, Object?>> records) =>
      records.map((record) => 'I/flutter: SKELETON_BENCHMARK ${jsonEncode(record)}').join('\n');

  SkeletonCrossfadeBenchmarkLogValidator validator({String variant = 'baseline'}) =>
      SkeletonCrossfadeBenchmarkLogValidator(
        runId: 'crossfade-test-run',
        variant: variant,
        source: '$variant-source',
        renderer: 'skia-opengles',
        topology: 'many',
        effect: 'static',
        cardCount: 12,
        warmupSwitches: 12,
        measuredSwitches: 40,
        requireBudgetPass: true,
        requireEnforced: true,
      );

  group('SkeletonCrossfadeBenchmarkLogValidator', () {
    test('when a complete baseline log is valid, it should accept it', () {
      final validation = validator().validate(logFor(records(variant: 'baseline')));

      expect(validation.issues, isEmpty);
    });

    test('when a complete candidate log is valid, it should accept it', () {
      final validation = validator(variant: 'candidate').validate(logFor(records(variant: 'candidate')));

      expect(validation.issues, isEmpty);
    });

    test('when a direction has a different run ID, it should reject the log', () {
      final sample = records(variant: 'baseline');
      sample[1]['run_id'] = 'another-process';

      expect(validator().validate(logFor(sample)).issues, contains('to_content has a different run ID.'));
    });

    test('when a direction is missing, it should reject the log', () {
      final sample = records(variant: 'baseline')..removeWhere((record) => record['path'] == 'to_skeleton');

      expect(validator().validate(logFor(sample)).issues, contains('Missing to_skeleton record.'));
    });

    test('when raster p99 exceeds the frame budget, it should reject the log', () {
      final sample = records(variant: 'baseline');
      sample[1]
        ..['raster'] = statistics(p99: 18000)
        ..['work_p99_within_budget'] = false;

      expect(validator().validate(logFor(sample)).issues, contains('to_content missed its build/raster p99 budget.'));
    });

    test('when aggregate frames are below per-switch minimums, it should reject the log', () {
      final sample = records(variant: 'baseline');
      sample[1]['frames'] = 100;

      expect(validator().validate(logFor(sample)).issues, contains('to_content has invalid per-switch frame counts.'));
    });

    test('when aggregate frames exceed per-switch maximums, it should reject the log', () {
      final sample = records(variant: 'baseline');
      sample[1]['frames'] = 400;

      expect(validator().validate(logFor(sample)).issues, contains('to_content has invalid per-switch frame counts.'));
    });

    test('when per-switch frame gap evidence is missing, it should reject the log', () {
      final sample = records(variant: 'baseline');
      sample[1].remove('worst_frame_start_gap_per_switch');

      expect(
        validator().validate(logFor(sample)).issues,
        contains('to_content worst_frame_start_gap_per_switch is missing statistics.'),
      );
    });
  });
}
