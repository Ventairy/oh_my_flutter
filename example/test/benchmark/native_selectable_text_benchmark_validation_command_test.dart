import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/native_selectable_text/validation_command.dart';

void main() {
  String buildLog({
    required bool budgetPassed,
    String scenario = 'selection',
  }) {
    const statistics = <String, num>{
      'mean_us': 1500,
      'p50_us': 1000,
      'p90_us': 2000,
      'p99_us': 3000,
      'max_us': 4000,
    };
    final records = <Map<String, Object>>[
      <String, Object>{
        'path': 'environment',
        'run_id': 'validation-command-run',
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
        'frame_budget_us': 16666,
        'logical_size': <String, double>{'width': 360, 'height': 800},
        'physical_size': <String, double>{'width': 1080, 'height': 2400},
        'device_pixel_ratio': 3.0,
        'warmup_frames': 30,
        'measured_frames': 60,
        'trials': 2,
        'configured_item_count': 240,
        'active_widget_count': 1,
        'frame_budget_enforced': true,
      },
      for (var trial = 1; trial <= 2; trial += 1)
        <String, Object>{
          'path': 'trial.$trial',
          'run_id': 'validation-command-run',
          'scenario': scenario,
          'widget': 'native',
          'text_case': 'paragraph',
          'trial': trial,
          'valid': true,
          'gate': true,
          'frames': 60,
          'build': statistics,
          'raster': statistics,
          'total_span': statistics,
          'vsync_overhead': statistics,
          'build_over_budget': 0,
          'raster_over_budget': 0,
          'total_span_over_budget': 0,
          'vsync_over_budget': 0,
          'work_over_budget': 0,
          'any_over_budget': 0,
          'longest_work_miss_streak': 0,
          'longest_any_miss_streak': 0,
          'work_p99_within_budget': true,
          'frame_budget_us': 16666,
        },
      <String, Object>{
        'path': 'acceptance',
        'run_id': 'validation-command-run',
        'scenario': scenario,
        'widget': 'native',
        'text_case': 'paragraph',
        'passed': budgetPassed,
        'enforced': true,
        'failed_trial_paths': <String>[],
        'trials': 2,
        'frames_per_trial': 60,
      },
    ];
    return records
        .map((record) {
          return 'NATIVE_SELECTABLE_TEXT_BENCHMARK ${jsonEncode(record)}';
        })
        .join('\n');
  }

  Future<({int code, bool artifactsExist})> runCommand({
    required bool budgetPassed,
    String scenario = 'selection',
  }) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'native-selectable-benchmark-command.',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final log = File('${temporaryDirectory.path}/flutter.log');
    await log.writeAsString(
      buildLog(budgetPassed: budgetPassed, scenario: scenario),
    );
    final artifacts = Directory('${temporaryDirectory.path}/artifacts');
    const command = NativeSelectableTextBenchmarkValidationCommand();
    final code = await command.run(
      <String>[
        '--log',
        log.path,
        '--output-directory',
        artifacts.path,
        '--expected-run-id',
        'validation-command-run',
        '--expected-renderer',
        'impeller-vulkan',
        '--expected-scenario',
        scenario,
        '--expected-widget',
        'native',
        '--expected-text-case',
        'paragraph',
        '--expected-item-count',
        '240',
        '--expected-warmup-frames',
        '30',
        '--expected-frames-per-trial',
        '60',
        '--require-budget-pass',
        '--require-enforced',
      ],
      output: StringBuffer(),
      errors: StringBuffer(),
    );
    return (
      code: code,
      artifactsExist:
          File(
            '${artifacts.path}/native_selectable_text_benchmark.jsonl',
          ).existsSync() &&
          File(
            '${artifacts.path}/native_selectable_text_benchmark_summary.txt',
          ).existsSync(),
    );
  }

  test(
    'when a validated run passes, it should return zero and write artifacts',
    () async {
      final result = await runCommand(budgetPassed: true);

      expect(result, (code: 0, artifactsExist: true));
    },
  );

  test(
    'when application acceptance is inconsistent, it should return nonzero',
    () async {
      final result = await runCommand(budgetPassed: false);

      expect(result.code, 1);
    },
  );

  test(
    'when menu_idle evidence is valid, it should return zero',
    () async {
      final result = await runCommand(
        budgetPassed: true,
        scenario: 'menu_idle',
      );

      expect(result.code, 0);
    },
  );
}
