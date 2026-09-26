import 'dart:convert';
import 'dart:io';

import 'skeleton_crossfade_benchmark_log_validator.dart';

/// Checks a captured crossfade profile run and writes its canonical records.
Future<void> main(List<String> arguments) async {
  final values = <String, String>{};
  final flags = <String>{};
  const knownFlags = <String>{'--require-budget-pass', '--require-enforced'};
  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    if (knownFlags.contains(argument)) {
      flags.add(argument);
    } else if (argument.startsWith('--') && index + 1 < arguments.length && !arguments[index + 1].startsWith('--')) {
      values[argument] = arguments[++index];
    } else {
      stderr.writeln('Unknown or incomplete argument: $argument');
      exitCode = 64;
      return;
    }
  }

  const required = <String>[
    '--log',
    '--output-directory',
    '--expected-run-id',
    '--expected-variant',
    '--expected-source',
    '--expected-renderer',
    '--expected-topology',
    '--expected-effect',
    '--expected-card-count',
    '--expected-warmup-switches',
    '--expected-measured-switches',
  ];
  final missing = required.where((argument) => !values.containsKey(argument)).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Missing required arguments: ${missing.join(', ')}');
    exitCode = 64;
    return;
  }

  try {
    final log = await File(values['--log']!).readAsString();
    final validator = SkeletonCrossfadeBenchmarkLogValidator(
      runId: values['--expected-run-id']!,
      variant: values['--expected-variant']!,
      source: values['--expected-source']!,
      renderer: values['--expected-renderer']!,
      topology: values['--expected-topology']!,
      effect: values['--expected-effect']!,
      cardCount: int.parse(values['--expected-card-count']!),
      warmupSwitches: int.parse(values['--expected-warmup-switches']!),
      measuredSwitches: int.parse(values['--expected-measured-switches']!),
      requireBudgetPass: flags.contains('--require-budget-pass'),
      requireEnforced: flags.contains('--require-enforced'),
    );
    final result = validator.validate(log);
    final output = Directory(values['--output-directory']!);
    await output.create(recursive: true);
    final records = result.records.map(jsonEncode).join('\n');
    await File('${output.path}/skeleton_crossfade_benchmark.jsonl').writeAsString('$records\n');
    final summary = StringBuffer()
      ..writeln('Skeleton crossfade log validation: ${result.issues.isEmpty ? 'PASS' : 'FAIL'}')
      ..writeln('Run: ${validator.runId}; variant: ${validator.variant}; source: ${validator.source}')
      ..writeln('Renderer: ${validator.renderer}; topology: ${validator.topology}; effect: ${validator.effect}')
      ..writeln(
        'Cards: ${validator.cardCount}; warmup switches: ${validator.warmupSwitches}; measured switches: ${validator.measuredSwitches}',
      );
    final acceptance = result.records.where((record) => record['path'] == 'acceptance');
    if (acceptance.isNotEmpty) {
      summary.writeln(
        'Application budget enforcement: ${acceptance.first['enforced']}; accepted: ${acceptance.first['passed']}',
      );
    }
    for (final path in const <String>['to_content', 'to_skeleton']) {
      final matches = result.records.where((record) => record['path'] == path);
      if (matches.isEmpty) continue;
      final record = matches.first;
      final build = record['build'] as Map<String, Object?>? ?? const <String, Object?>{};
      final raster = record['raster'] as Map<String, Object?>? ?? const <String, Object?>{};
      final worstBuild = record['worst_build_per_switch'] as Map<String, Object?>? ?? const <String, Object?>{};
      final worstRaster = record['worst_raster_per_switch'] as Map<String, Object?>? ?? const <String, Object?>{};
      final worstGap = record['worst_frame_start_gap_per_switch'] as Map<String, Object?>? ?? const <String, Object?>{};
      summary.writeln(
        '$path: frames=${record['frames']} (${record['min_frames_per_switch']}..${record['max_frames_per_switch']} per switch), '
        'probe_paints=${record['probe_paints']}, '
        'build_p50/p99_us=${build['p50_us']}/${build['p99_us']}, '
        'raster_p50/p99_us=${raster['p50_us']}/${raster['p99_us']}, '
        'worst_build/raster_per_switch_p99_us=${worstBuild['p99_us']}/${worstRaster['p99_us']}, '
        'worst_frame_start_gap_per_switch_p99_us=${worstGap['p99_us']}, '
        'long_gap_switches=${record['switches_with_long_frame_start_gap']}, '
        'budget_us=${record['frame_budget_us']}, '
        'work_p99_within_budget=${record['work_p99_within_budget']}, '
        'build/raster_over_budget=${record['build_over_budget']}/${record['raster_over_budget']}',
      );
    }
    for (final issue in result.issues) {
      summary.writeln('- $issue');
    }
    await File('${output.path}/skeleton_crossfade_benchmark_summary.txt').writeAsString(summary.toString());
    stdout.write(summary);
    if (result.issues.isNotEmpty) exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('Unable to validate crossfade benchmark log: $error');
    exitCode = 1;
  }
}
