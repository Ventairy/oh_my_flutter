import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_validation_command.dart';

void main() {
  String buildLog({required bool acceptancePassed}) {
    final records = <Map<String, Object?>>[
      <String, Object?>{
        'path': 'environment',
        'mode': 'profile',
        'renderer': 'impeller-vulkan',
        'refresh_rate_hz': 120.0,
        'scenarios': <String>['text'],
        'steady_trials': 2,
        'steady_frames_per_trial': 3,
      },
    ];
    for (var trial = 1; trial <= 2; trial += 1) {
      for (final direction in const <String>['forward', 'reverse']) {
        records.add(<String, Object?>{
          'path': 'text.steady.$direction.trial_$trial',
          'scenario': 'text',
          'phase': 'steady',
          'direction': direction,
          'trial': trial,
          'attempt': 1,
          'retried': false,
          'frames': 3,
          'work_p99_within_budget': true,
          'gate': true,
        });
      }
    }
    var failedSteadyPaths = <String>[];
    if (!acceptancePassed) {
      failedSteadyPaths = <String>['text.steady.forward.trial_1'];
    }
    records.add(<String, Object?>{
      'path': 'acceptance',
      'passed': acceptancePassed,
      'enforced': true,
      'failed_steady_paths': failedSteadyPaths,
      'steady_trials': 2,
      'steady_frames_per_trial': 3,
      'invalid_trial_attempts': 0,
      'retried_trials': 0,
    });
    return records
        .map((record) {
          return 'MORPH_BENCHMARK ${jsonEncode(record)}';
        })
        .join('\n');
  }

  Future<
    ({
      int exitCode,
      bool jsonLinesWritten,
      bool summaryWritten,
    })
  >
  runCommand({required bool acceptancePassed}) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'morph-benchmark-validator-test.',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final logFile = File('${temporaryDirectory.path}/flutter.log');
    await logFile.writeAsString(
      buildLog(acceptancePassed: acceptancePassed),
    );
    final artifactDirectory = Directory(
      '${temporaryDirectory.path}/artifacts',
    );
    final exitCode = await const MorphBenchmarkValidationCommand().run(
      <String>[
        '--log',
        logFile.path,
        '--output-directory',
        artifactDirectory.path,
        '--expected-scenarios',
        'text',
        '--minimum-frames',
        '3',
        '--require-budget-pass',
        '--require-enforced',
      ],
      output: StringBuffer(),
      errors: StringBuffer(),
    );
    return (
      exitCode: exitCode,
      jsonLinesWritten: File(
        '${artifactDirectory.path}/morph_benchmark.jsonl',
      ).existsSync(),
      summaryWritten: File(
        '${artifactDirectory.path}/morph_benchmark_summary.txt',
      ).existsSync(),
    );
  }

  group('MorphBenchmarkValidationCommand', () {
    test(
      'when validation passes, it should write both artifacts and exit zero',
      () async {
        final result = await runCommand(acceptancePassed: true);

        expect(
          result,
          (exitCode: 0, jsonLinesWritten: true, summaryWritten: true),
        );
      },
    );

    test(
      'when application acceptance fails, '
      'it should write both artifacts and exit nonzero',
      () async {
        final result = await runCommand(acceptancePassed: false);

        expect(
          result,
          (exitCode: 1, jsonLinesWritten: true, summaryWritten: true),
        );
      },
    );
  });
}
