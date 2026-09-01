import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/interactive_swipe_dismiss/interactive_swipe_dismiss_benchmark_record_buffer.dart';
import '../../benchmark/interactive_swipe_dismiss/interactive_swipe_dismiss_benchmark_validation_command.dart';

void main() {
  const runId = 'interactive-swipe-dismiss-command-run';
  const renderer = 'impeller-vulkan';
  const frames = 2;
  const warmupFrames = 2;
  const frameBudget = 16666;
  const rawTimings = <int>[1000, 1000];
  const rawDispatch = <int>[20, 20];
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

  String buildRetainedLog() {
    final records = <Map<String, Object>>[
      <String, Object>{
        'path': 'environment',
        'run_id': runId,
        'mode': 'profile',
        'renderer': renderer,
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
        'require_retained_paint': true,
        'warmup_frames_per_trial': warmupFrames,
        'steady_trials': 2,
        'steady_frames_per_trial': frames,
        'maximum_trial_attempts': 3,
      },
    ];
    for (var trial = 1; trial <= 2; trial += 1) {
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
          'build': rawTimings,
          'raster': rawTimings,
          'total_span': rawTimings,
          'vsync_overhead': rawTimings,
        },
        'build': timingStatistics,
        'raster': timingStatistics,
        'total_span': timingStatistics,
        'vsync_overhead': timingStatistics,
        'dispatch_durations_us': rawDispatch,
        'dispatch': dispatchStatistics,
        'probe_builds': 0,
        'probe_layouts': 0,
        'probe_paints': 0,
        'retained_paint_required': true,
        'scroll_start_px': 600.0,
        'scroll_end_px': 600.0,
        'maximum_scroll_drift_px': 0.0,
        'dismiss_callbacks': 0,
        'maximum_transient_callbacks': 1,
        'maximum_raw_primary_px': 120.0,
        'dismiss_distance_px': 200.0,
        'build_over_budget': 0,
        'raster_over_budget': 0,
        'total_span_over_budget': 0,
        'any_over_budget': 0,
        'longest_consecutive_misses': 0,
        'work_p99_within_budget': true,
        'structural_invariants_passed': true,
        'frame_budget_us': frameBudget,
      });
    }
    records.add(<String, Object>{
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
        .map((record) {
          return 'flutter: '
              '${InteractiveSwipeDismissBenchmarkRecordBuffer.recordMarker}'
              '${jsonEncode(record)}';
        })
        .join('\n');
  }

  List<String> arguments({
    required String logPath,
    required String outputDirectory,
  }) {
    return <String>[
      '--log',
      logPath,
      '--output-directory',
      outputDirectory,
      '--expected-run-id',
      runId,
      '--expected-renderer',
      renderer,
      '--expected-warmup-frames',
      '$warmupFrames',
      '--expected-frames-per-trial',
      '$frames',
      '--require-budget-pass',
      '--require-enforced',
      '--require-retained-paint',
    ];
  }

  group('InteractiveSwipeDismissBenchmarkValidationCommand', () {
    test(
      'when the retained workload passes, '
      'it should write artifacts and exit zero',
      () async {
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'interactive-swipe-dismiss-validator-test.',
        );
        addTearDown(() => temporaryDirectory.delete(recursive: true));
        final logFile = File('${temporaryDirectory.path}/flutter.log');
        await logFile.writeAsString(buildRetainedLog());
        final artifactDirectory = Directory(
          '${temporaryDirectory.path}/artifacts',
        );
        final output = StringBuffer();
        final errors = StringBuffer();
        const command = InteractiveSwipeDismissBenchmarkValidationCommand();
        final exitCode = await command.run(
          arguments(
            logPath: logFile.path,
            outputDirectory: artifactDirectory.path,
          ),
          output: output,
          errors: errors,
        );
        final jsonLinesFile = File(
          '${artifactDirectory.path}/'
          'interactive_swipe_dismiss_benchmark.jsonl',
        );
        final summaryFile = File(
          '${artifactDirectory.path}/'
          'interactive_swipe_dismiss_benchmark_summary.txt',
        );

        expect(
          <String, Object>{
            'exit_code': exitCode,
            'json_lines_exist': jsonLinesFile.existsSync(),
            'summary_passed': (await summaryFile.readAsString()).startsWith(
              'InteractiveSwipeDismiss benchmark host validation: PASS\n',
            ),
            'errors': errors.toString(),
          },
          <String, Object>{
            'exit_code': 0,
            'json_lines_exist': true,
            'summary_passed': true,
            'errors': '',
          },
        );
      },
    );

    test(
      'when help is requested, it should name every strict gate and exit zero',
      () async {
        final output = StringBuffer();
        final errors = StringBuffer();
        const command = InteractiveSwipeDismissBenchmarkValidationCommand();
        final exitCode = await command.run(
          <String>['--help'],
          output: output,
          errors: errors,
        );

        expect(
          <String, Object>{
            'exit_code': exitCode,
            'retained_gate': output.toString().contains(
              '--require-retained-paint',
            ),
            'run_id': output.toString().contains('--expected-run-id'),
            'errors': errors.toString(),
          },
          <String, Object>{
            'exit_code': 0,
            'retained_gate': true,
            'run_id': true,
            'errors': '',
          },
        );
      },
    );

    test(
      'when required options are missing, '
      'it should reject the command before reading a log',
      () async {
        final output = StringBuffer();
        final errors = StringBuffer();
        const command = InteractiveSwipeDismissBenchmarkValidationCommand();
        final exitCode = await command.run(
          const <String>[],
          output: output,
          errors: errors,
        );

        expect(
          <String, Object>{
            'exit_code': exitCode,
            'output': output.toString(),
            'missing': errors.toString().contains(
              'Missing required options:',
            ),
          },
          <String, Object>{
            'exit_code': 1,
            'output': '',
            'missing': true,
          },
        );
      },
    );
  });
}
