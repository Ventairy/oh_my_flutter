import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/skeleton/skeleton_benchmark_validation_command.dart';

void main() {
  const runId = 'skeleton-command-test-run';
  const renderer = 'skia-opengles';
  const frames = 60;
  const warmupFrames = 30;
  const frameBudget = 16666;

  List<Map<String, Object?>> buildRecords({
    required bool acceptancePassed,
  }) {
    final records = <Map<String, Object?>>[
      <String, Object?>{
        'path': 'environment',
        'run_id': runId,
        'mode': 'profile',
        'renderer': renderer,
        'effect': 'shimmer',
        'topology': 'single',
        'card_count': 16,
        'refresh_rate_hz': 60.0,
        'frame_budget_us': frameBudget,
        'logical_size': <String, double>{'width': 360, 'height': 640},
        'physical_size': <String, double>{'width': 720, 'height': 1280},
        'device_pixel_ratio': 2.0,
        'animations_disabled': false,
        'warmup_frames_per_trial': warmupFrames,
        'steady_trials': 2,
        'steady_frames_per_trial': frames,
        'maximum_trial_attempts': 3,
      },
    ];
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
        'probe_paints': 0,
        'transient_callbacks': 1,
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
        'structural_invariants_passed': true,
        'frame_budget_us': frameBudget,
      });
    }
    records.add(<String, Object?>{
      'path': 'acceptance',
      'run_id': runId,
      'passed': acceptancePassed,
      'enforced': true,
      'failed_steady_paths': <String>[],
      'steady_trials': 2,
      'steady_frames_per_trial': frames,
      'maximum_trial_attempts': 3,
      'invalid_trial_attempts': 0,
      'retried_trials': 0,
    });
    return records;
  }

  String buildLog({required bool acceptancePassed}) {
    return buildRecords(acceptancePassed: acceptancePassed)
        .map((record) {
          return 'flutter: SKELETON_BENCHMARK ${jsonEncode(record)}';
        })
        .join('\n');
  }

  List<String> arguments({
    required String logPath,
    required String outputDirectory,
    String expectedEffect = 'shimmer',
    String expectedTopology = 'single',
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
      '--expected-effect',
      expectedEffect,
      '--expected-topology',
      expectedTopology,
      '--expected-card-count',
      '16',
      '--expected-warmup-frames',
      '$warmupFrames',
      '--expected-frames-per-trial',
      '$frames',
      '--require-budget-pass',
      '--require-enforced',
    ];
  }

  Future<
    ({
      String errors,
      int exitCode,
      String jsonLines,
      String output,
      String summary,
    })
  >
  runCommand({
    required bool acceptancePassed,
    String expectedEffect = 'shimmer',
    String expectedTopology = 'single',
  }) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'skeleton-benchmark-validator-test.',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final logFile = File('${temporaryDirectory.path}/flutter.log');
    await logFile.writeAsString(
      buildLog(acceptancePassed: acceptancePassed),
    );
    final artifactDirectory = Directory(
      '${temporaryDirectory.path}/artifacts',
    );
    final output = StringBuffer();
    final errors = StringBuffer();
    final exitCode = await const SkeletonBenchmarkValidationCommand().run(
      arguments(
        logPath: logFile.path,
        outputDirectory: artifactDirectory.path,
        expectedEffect: expectedEffect,
        expectedTopology: expectedTopology,
      ),
      output: output,
      errors: errors,
    );
    final jsonLinesFile = File(
      '${artifactDirectory.path}/skeleton_benchmark.jsonl',
    );
    final summaryFile = File(
      '${artifactDirectory.path}/skeleton_benchmark_summary.txt',
    );
    var jsonLines = '';
    if (jsonLinesFile.existsSync()) {
      jsonLines = await jsonLinesFile.readAsString();
    }
    var summary = '';
    if (summaryFile.existsSync()) {
      summary = await summaryFile.readAsString();
    }
    return (
      errors: errors.toString(),
      exitCode: exitCode,
      jsonLines: jsonLines,
      output: output.toString(),
      summary: summary,
    );
  }

  group('SkeletonBenchmarkValidationCommand', () {
    test(
      'when the exact Skeleton workload passes, '
      'it should write Skeleton artifacts and exit zero',
      () async {
        final result = await runCommand(acceptancePassed: true);
        final expectedJsonLines = buildRecords(
          acceptancePassed: true,
        ).map(jsonEncode).join('\n');

        expect(
          <String, Object>{
            'exit_code': result.exitCode,
            'json_lines': result.jsonLines,
            'summary_passed': result.summary.startsWith(
              'Skeleton benchmark host validation: PASS\n',
            ),
            'summary_run_id': result.summary.contains('Run ID: $runId\n'),
            'output_names_artifacts':
                result.output.contains('skeleton_benchmark.jsonl') &&
                result.output.contains('skeleton_benchmark_summary.txt'),
            'errors': result.errors,
          },
          <String, Object>{
            'exit_code': 0,
            'json_lines': '$expectedJsonLines\n',
            'summary_passed': true,
            'summary_run_id': true,
            'output_names_artifacts': true,
            'errors': '',
          },
        );
      },
    );

    test(
      'when application acceptance fails, '
      'it should still write both artifacts and exit nonzero',
      () async {
        final result = await runCommand(acceptancePassed: false);

        expect(
          <String, Object>{
            'exit_code': result.exitCode,
            'json_lines_written': result.jsonLines.isNotEmpty,
            'summary_failed': result.summary.startsWith(
              'Skeleton benchmark host validation: FAIL\n',
            ),
            'errors': result.errors,
          },
          <String, Object>{
            'exit_code': 1,
            'json_lines_written': true,
            'summary_failed': true,
            'errors': '',
          },
        );
      },
    );

    test(
      'when the CLI workload does not match the log, '
      'it should preserve the exact mismatch in the failed summary',
      () async {
        final result = await runCommand(
          acceptancePassed: true,
          expectedTopology: 'many',
        );

        expect(
          <String, Object>{
            'exit_code': result.exitCode,
            'summary_failed': result.summary.startsWith(
              'Skeleton benchmark host validation: FAIL\n',
            ),
            'summary_names_expected_workload': result.summary.contains(
              'Workload: effect=shimmer; topology=many; cards=16',
            ),
            'summary_names_actual_mismatch': result.summary.contains(
              'Environment topology must be many; got single.',
            ),
          },
          <String, Object>{
            'exit_code': 1,
            'summary_failed': true,
            'summary_names_expected_workload': true,
            'summary_names_actual_mismatch': true,
          },
        );
      },
    );

    test(
      'when help is requested, '
      'it should describe the exact Skeleton CLI and exit zero',
      () async {
        final output = StringBuffer();
        final errors = StringBuffer();
        final exitCode = await const SkeletonBenchmarkValidationCommand().run(
          <String>['--help'],
          output: output,
          errors: errors,
        );

        expect(
          <String, Object>{
            'exit_code': exitCode,
            'entrypoint': output.toString().contains(
              'benchmark/skeleton/validate_skeleton_benchmark_log.dart',
            ),
            'effect_schema': output.toString().contains(
              '--expected-effect <fade|shimmer>',
            ),
            'topology_schema': output.toString().contains(
              '--expected-topology <single|many>',
            ),
            'errors': errors.toString(),
          },
          <String, Object>{
            'exit_code': 0,
            'entrypoint': true,
            'effect_schema': true,
            'topology_schema': true,
            'errors': '',
          },
        );
      },
    );

    test(
      'when required options are missing, '
      'it should reject the CLI before reading a log',
      () async {
        final output = StringBuffer();
        final errors = StringBuffer();
        final exitCode = await const SkeletonBenchmarkValidationCommand().run(
          const <String>[],
          output: output,
          errors: errors,
        );

        expect(
          <String, Object>{
            'exit_code': exitCode,
            'output': output.toString(),
            'missing_options': errors.toString().contains(
              'Missing required options:',
            ),
            'skeleton_usage': errors.toString().contains(
              'benchmark/skeleton/validate_skeleton_benchmark_log.dart',
            ),
          },
          <String, Object>{
            'exit_code': 1,
            'output': '',
            'missing_options': true,
            'skeleton_usage': true,
          },
        );
      },
    );

    test(
      'when the effect is outside the Skeleton CLI schema, '
      'it should reject the value before reading a log',
      () async {
        final output = StringBuffer();
        final errors = StringBuffer();
        final exitCode = await const SkeletonBenchmarkValidationCommand().run(
          arguments(
            logPath: 'unused.log',
            outputDirectory: 'unused-artifacts',
            expectedEffect: 'pulse',
          ),
          output: output,
          errors: errors,
        );

        expect(
          <String, Object>{
            'exit_code': exitCode,
            'output': output.toString(),
            'invalid_effect': errors.toString().contains(
              '--expected-effect must be fade or shimmer.',
            ),
          },
          <String, Object>{
            'exit_code': 1,
            'output': '',
            'invalid_effect': true,
          },
        );
      },
    );

    test(
      'when a value option is repeated, '
      'it should reject the ambiguous CLI',
      () async {
        final output = StringBuffer();
        final errors = StringBuffer();
        final commandArguments = arguments(
          logPath: 'unused.log',
          outputDirectory: 'unused-artifacts',
        )..addAll(const <String>['--expected-run-id', 'another-run']);
        final exitCode = await const SkeletonBenchmarkValidationCommand().run(
          commandArguments,
          output: output,
          errors: errors,
        );

        expect(
          <String, Object>{
            'exit_code': exitCode,
            'output': output.toString(),
            'duplicate_option': errors.toString().contains(
              '--expected-run-id must be supplied exactly once.',
            ),
          },
          <String, Object>{
            'exit_code': 1,
            'output': '',
            'duplicate_option': true,
          },
        );
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
