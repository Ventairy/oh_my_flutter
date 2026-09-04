import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/native_selectable_text/log_validator.dart';
import '../../benchmark/native_selectable_text/record_buffer.dart';

void main() {
  List<Map<String, Object>> buildRecords({
    bool budgetPassed = true,
    bool enforced = true,
    int frameBudget = 16666,
    bool acceptancePassedIsConsistent = true,
    String scenario = 'selection',
  }) {
    const frames = 60;
    final statistics = <String, num>{
      'mean_us': budgetPassed ? 1500 : 10000,
      'p50_us': 1000,
      'p90_us': 2000,
      'p99_us': budgetPassed ? 3000 : 20000,
      'max_us': budgetPassed ? 4000 : 24000,
    };
    final missCount = budgetPassed ? 0 : 1;
    final records = <Map<String, Object>>[
      <String, Object>{
        'path': 'environment',
        'run_id': 'native-selectable-test-run',
        'mode': 'profile',
        'platform': 'android',
        'operating_system': 'Android 13',
        'renderer': 'impeller-vulkan',
        'renderer_source': 'manually verified startup or device logs',
        'scenario': scenario,
        'widget': 'native',
        'text_case': 'paragraph',
        'text_code_units': 256,
        'inline_span_count': 1,
        'refresh_rate_hz': 60.0,
        'frame_budget_us': frameBudget,
        'logical_size': <String, double>{'width': 360, 'height': 800},
        'physical_size': <String, double>{'width': 1080, 'height': 2400},
        'device_pixel_ratio': 3.0,
        'warmup_frames': 30,
        'measured_frames': frames,
        'trials': 2,
        'configured_item_count': 240,
        'active_widget_count': 1,
        'frame_budget_enforced': enforced,
      },
    ];
    for (var trial = 1; trial <= 2; trial += 1) {
      records.add(<String, Object>{
        'path': 'trial.$trial',
        'run_id': 'native-selectable-test-run',
        'scenario': scenario,
        'widget': 'native',
        'text_case': 'paragraph',
        'trial': trial,
        'valid': true,
        'gate': true,
        'frames': frames,
        'build': statistics,
        'raster': statistics,
        'total_span': statistics,
        'vsync_overhead': statistics,
        'build_over_budget': missCount,
        'raster_over_budget': missCount,
        'total_span_over_budget': missCount,
        'vsync_over_budget': missCount,
        'work_over_budget': missCount,
        'any_over_budget': missCount,
        'longest_work_miss_streak': missCount,
        'longest_any_miss_streak': missCount,
        'work_p99_within_budget': budgetPassed,
        'frame_budget_us': frameBudget,
      });
    }
    final reportedAcceptance = acceptancePassedIsConsistent == budgetPassed;
    final failedTrialPaths = <String>[];
    if (!budgetPassed) {
      failedTrialPaths.addAll(<String>['trial.1', 'trial.2']);
    }
    records.add(<String, Object>{
      'path': 'acceptance',
      'run_id': 'native-selectable-test-run',
      'scenario': scenario,
      'widget': 'native',
      'text_case': 'paragraph',
      'passed': reportedAcceptance,
      'enforced': enforced,
      'failed_trial_paths': failedTrialPaths,
      'trials': 2,
      'frames_per_trial': frames,
    });
    return records;
  }

  String buildLog({
    bool budgetPassed = true,
    bool enforced = true,
    int frameBudget = 16666,
    bool acceptancePassedIsConsistent = true,
    String scenario = 'selection',
  }) {
    return buildRecords(
          budgetPassed: budgetPassed,
          enforced: enforced,
          frameBudget: frameBudget,
          acceptancePassedIsConsistent: acceptancePassedIsConsistent,
          scenario: scenario,
        )
        .map((record) {
          return 'flutter: NATIVE_SELECTABLE_TEXT_BENCHMARK '
              '${jsonEncode(record)}';
        })
        .join('\n');
  }

  NativeSelectableTextBenchmarkLogValidator validator({
    bool requireBudgetPass = true,
    bool requireEnforcedBudget = true,
    String scenario = 'selection',
  }) {
    return NativeSelectableTextBenchmarkLogValidator(
      expectedRunId: 'native-selectable-test-run',
      expectedRenderer: 'impeller-vulkan',
      expectedScenario: scenario,
      expectedWidget: 'native',
      expectedTextCase: 'paragraph',
      expectedItemCount: 240,
      expectedWarmupFrames: 30,
      expectedFramesPerTrial: 60,
      requireBudgetPass: requireBudgetPass,
      requireEnforcedBudget: requireEnforcedBudget,
    );
  }

  group('NativeSelectableTextBenchmarkLogValidator', () {
    test('when a complete physical-device log passes, it should accept it', () {
      final validation = validator().validate(buildLog());

      expect(validation.passed, isTrue);
    });

    test(
      'when a complete menu_idle log passes, it should accept it',
      () {
        final validation = validator(
          scenario: 'menu_idle',
        ).validate(buildLog(scenario: 'menu_idle'));

        expect(validation.passed, isTrue);
      },
    );

    test(
      'when a measured trial is missing, it should reject the log',
      () {
        final lines = buildLog().split('\n')..removeAt(2);
        final validation = validator().validate(lines.join('\n'));

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when the frame budget disagrees with refresh rate, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(frameBudget: 8333),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when application acceptance contradicts its trials, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(acceptancePassedIsConsistent: false),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a complete baseline misses its budget, '
      'it should distinguish evidence validity from the performance gate',
      () {
        final log = buildLog(budgetPassed: false);
        final evidenceOnly = validator(
          requireBudgetPass: false,
        ).validate(log);
        final gated = validator().validate(log);

        expect(
          (evidenceOnly: evidenceOnly.passed, gated: gated.passed),
          (evidenceOnly: true, gated: false),
        );
      },
    );

    test(
      'when a record exceeds device log limits, '
      'it should reconstruct and validate every chunk',
      () {
        final records = buildRecords();
        records.last['diagnostic_padding'] = List<String>.filled(
          6000,
          'x',
        ).join();
        final emitted = <String>[];
        final buffer = NativeSelectableTextBenchmarkRecordBuffer(emitted.add);
        records.forEach(buffer.add);
        buffer.flush();
        final log = emitted.map((line) => 'flutter: $line').join('\n');

        expect(validator().validate(log).passed, isTrue);
      },
    );
  });
}
