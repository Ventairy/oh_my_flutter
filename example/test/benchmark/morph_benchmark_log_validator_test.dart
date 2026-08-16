import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_log_validator.dart';
import '../../benchmark/morph/morph_benchmark_record_buffer.dart';

void main() {
  String buildLog({
    bool acceptancePassed = true,
    int frames = 150,
    String mode = 'profile',
    bool retried = false,
    List<String> scenarios = const <String>['text', 'surface'],
  }) {
    final records = <Map<String, Object?>>[
      <String, Object?>{
        'path': 'environment',
        'mode': mode,
        'renderer': 'impeller-vulkan',
        'refresh_rate_hz': 120.0,
        'scenarios': scenarios,
        'steady_trials': 2,
        'steady_frames_per_trial': frames,
      },
    ];
    for (final scenario in scenarios) {
      for (var trial = 1; trial <= 2; trial += 1) {
        if (retried && scenario == scenarios.first && trial == 1) {
          records.add(<String, Object?>{
            'path': '$scenario.steady.trial_1.invalid.attempt_1',
            'scenario': scenario,
            'phase': 'steady',
            'trial': 1,
            'attempt': 1,
            'valid': false,
            'invalid_direction': 'forward',
            'invalid_reasons': <String>['view_focus_changed'],
            'retrying': true,
          });
        }
        for (final direction in const <String>['forward', 'reverse']) {
          final isFirstScenario = scenario == scenarios.first;
          final isFirstTrial = trial == 1;
          final isRetriedTrial = retried && isFirstScenario && isFirstTrial;
          final attempt = isRetriedTrial ? 2 : 1;
          records.add(<String, Object?>{
            'path': '$scenario.steady.$direction.trial_$trial',
            'scenario': scenario,
            'phase': 'steady',
            'direction': direction,
            'trial': trial,
            'attempt': attempt,
            'retried': attempt > 1,
            'frames': frames,
            'work_p99_within_budget': true,
            'gate': true,
          });
        }
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
      'steady_frames_per_trial': frames,
      'invalid_trial_attempts': retried ? 1 : 0,
      'retried_trials': retried ? 1 : 0,
    });
    return records
        .map(
          (record) => 'flutter: MORPH_BENCHMARK ${jsonEncode(record)}',
        )
        .join('\n');
  }

  MorphBenchmarkLogValidator validator({
    List<String> scenarios = const <String>['text', 'surface'],
  }) {
    return MorphBenchmarkLogValidator(
      expectedScenarioIds: scenarios,
      requireBudgetPass: true,
      requireEnforcedBudget: true,
    );
  }

  group('MorphBenchmarkLogValidator', () {
    test('when a complete host log passes, it should accept it', () {
      final validation = validator().validate(buildLog());

      expect(validation.passed, isTrue);
    });

    test(
      'when application acceptance is false despite shell success, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(acceptancePassed: false),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a complete record is emitted in bounded chunks, '
      'it should reconstruct and validate it',
      () {
        final ordinaryLog = buildLog();
        final acceptanceLine = ordinaryLog.split('\n').last;
        final acceptance = Map<String, Object>.from(
          jsonDecode(
                acceptanceLine.substring(
                  acceptanceLine.indexOf('{'),
                ),
              )
              as Map<String, Object?>,
        );
        acceptance['diagnostic_padding'] = List<String>.filled(
          5000,
          'x',
        ).join();
        final emitted = <String>[];
        MorphBenchmarkRecordBuffer(emitted.add)
          ..add(acceptance)
          ..flush();
        final lines = ordinaryLog.split('\n');
        final withoutAcceptance = lines.take(lines.length - 1).join('\n');
        final chunkedLog = <String>[
          withoutAcceptance,
          ...emitted.map((line) => 'flutter: $line'),
        ].join('\n');

        final validation = validator().validate(chunkedLog);

        expect(validation.passed, isTrue);
      },
    );

    test('when required records are missing, it should reject the log', () {
      final validation = validator().validate('flutter run exited normally');

      expect(validation.passed, isFalse);
    });

    test(
      'when the application mode is not profile, it should reject the log',
      () {
        final validation = validator().validate(buildLog(mode: 'debug'));

        expect(validation.passed, isFalse);
      },
    );

    test('when the exact scenario set differs, it should reject the log', () {
      final validation = validator().validate(
        buildLog(scenarios: const <String>['text']),
      );

      expect(validation.passed, isFalse);
    });

    test('when a steady gate has too few frames, it should reject the log', () {
      final validation = validator().validate(buildLog(frames: 149));

      expect(validation.passed, isFalse);
    });

    test(
      'when an interrupted trial succeeds on retry, '
      'it should surface both events',
      () {
        final validation = validator().validate(buildLog(retried: true));

        expect(
          (
            passed: validation.passed,
            invalidSurfaced: validation.summary.contains(
              'Invalid attempt details:',
            ),
            retrySurfaced: validation.summary.contains(
              'Completed retry details:',
            ),
          ),
          (passed: true, invalidSurfaced: true, retrySurfaced: true),
        );
      },
    );
  });
}
