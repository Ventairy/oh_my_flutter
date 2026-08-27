import 'dart:io';

import 'skeleton_benchmark_log_validator.dart';

/// Runs host-side validation for a captured Skeleton benchmark log.
final class SkeletonBenchmarkValidationCommand {
  /// Creates the Skeleton benchmark validation command.
  const SkeletonBenchmarkValidationCommand();

  static const String _jsonLinesFileName = 'skeleton_benchmark.jsonl';
  static const String _summaryFileName = 'skeleton_benchmark_summary.txt';

  /// Validates [arguments], writes validation artifacts, and returns an exit
  /// code suitable for an acceptance gate.
  Future<int> run(
    List<String> arguments, {
    StringSink? output,
    StringSink? errors,
  }) async {
    final outputSink = output ?? stdout;
    final errorSink = errors ?? stderr;
    try {
      if (arguments.contains('--help')) {
        outputSink.writeln(_usage);
        return 0;
      }
      final options = _parse(arguments);
      final log = await File(options.logPath).readAsString();
      final validation = SkeletonBenchmarkLogValidator(
        expectedRunId: options.expectedRunId,
        expectedRenderer: options.expectedRenderer,
        expectedEffect: options.expectedEffect,
        expectedTopology: options.expectedTopology,
        expectedCardCount: options.expectedCardCount,
        expectedWarmupFrames: options.expectedWarmupFrames,
        expectedFramesPerTrial: options.expectedFramesPerTrial,
        requireBudgetPass: options.requireBudgetPass,
        requireEnforcedBudget: options.requireEnforcedBudget,
      ).validate(log);
      final outputDirectory = Directory(options.outputDirectory);
      await outputDirectory.create(recursive: true);
      final jsonLinesFile = File(
        '${outputDirectory.path}/$_jsonLinesFileName',
      );
      final summaryFile = File('${outputDirectory.path}/$_summaryFileName');
      await jsonLinesFile.writeAsString(validation.extractedJsonLines);
      await summaryFile.writeAsString(validation.summary);

      outputSink
        ..write(validation.summary)
        ..writeln('Extracted records: ${jsonLinesFile.path}')
        ..writeln('Validation summary: ${summaryFile.path}');
      return validation.passed ? 0 : 1;
    } on Object catch (error) {
      errorSink
        ..writeln('Skeleton benchmark log validation could not run: $error')
        ..writeln(_usage);
      return 1;
    }
  }

  ({
    int expectedCardCount,
    String expectedEffect,
    int expectedFramesPerTrial,
    String expectedRenderer,
    String expectedRunId,
    String expectedTopology,
    int expectedWarmupFrames,
    String logPath,
    String outputDirectory,
    bool requireBudgetPass,
    bool requireEnforcedBudget,
  })
  _parse(List<String> arguments) {
    final values = <String, String>{};
    final flags = <String>{};
    const valueOptions = <String>{
      '--log',
      '--output-directory',
      '--expected-run-id',
      '--expected-renderer',
      '--expected-effect',
      '--expected-topology',
      '--expected-card-count',
      '--expected-warmup-frames',
      '--expected-frames-per-trial',
    };
    const flagOptions = <String>{
      '--require-budget-pass',
      '--require-enforced',
    };

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      if (valueOptions.contains(argument)) {
        if (values.containsKey(argument)) {
          throw FormatException('$argument must be supplied exactly once.');
        }
        values[argument] = _followingValue(arguments, ++index, argument);
        continue;
      }
      if (flagOptions.contains(argument)) {
        if (!flags.add(argument)) {
          throw FormatException('$argument must not be repeated.');
        }
        continue;
      }
      throw FormatException('Unknown argument: $argument');
    }

    final missing = <String>[];
    for (final option in valueOptions) {
      if (!values.containsKey(option)) missing.add(option);
    }
    if (missing.isNotEmpty) {
      throw FormatException('Missing required options: ${missing.join(', ')}.');
    }

    final expectedCardCount = _positiveInteger(
      values['--expected-card-count']!,
      '--expected-card-count',
    );
    final expectedWarmupFrames = _positiveInteger(
      values['--expected-warmup-frames']!,
      '--expected-warmup-frames',
    );
    final expectedFramesPerTrial = _positiveInteger(
      values['--expected-frames-per-trial']!,
      '--expected-frames-per-trial',
    );
    final expectedEffect = values['--expected-effect']!;
    if (expectedEffect != 'fade' && expectedEffect != 'shimmer') {
      throw const FormatException('--expected-effect must be fade or shimmer.');
    }
    final expectedTopology = values['--expected-topology']!;
    if (expectedTopology != 'single' && expectedTopology != 'many') {
      throw const FormatException(
        '--expected-topology must be single or many.',
      );
    }
    _requireNonPlaceholder(
      values['--expected-run-id']!,
      '--expected-run-id',
    );
    _requireNonPlaceholder(
      values['--expected-renderer']!,
      '--expected-renderer',
    );

    return (
      expectedCardCount: expectedCardCount,
      expectedEffect: expectedEffect,
      expectedFramesPerTrial: expectedFramesPerTrial,
      expectedRenderer: values['--expected-renderer']!,
      expectedRunId: values['--expected-run-id']!,
      expectedTopology: expectedTopology,
      expectedWarmupFrames: expectedWarmupFrames,
      logPath: values['--log']!,
      outputDirectory: values['--output-directory']!,
      requireBudgetPass: flags.contains('--require-budget-pass'),
      requireEnforcedBudget: flags.contains('--require-enforced'),
    );
  }

  String _followingValue(
    List<String> arguments,
    int index,
    String option,
  ) {
    if (index >= arguments.length || arguments[index].startsWith('--')) {
      throw FormatException('$option requires a value.');
    }
    return arguments[index];
  }

  int _positiveInteger(String value, String option) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) {
      throw FormatException('$option must be a positive integer.');
    }
    return parsed;
  }

  void _requireNonPlaceholder(String value, String option) {
    if (value.trim().isEmpty || value.trim().toLowerCase() == 'unspecified') {
      throw FormatException('$option must be a non-placeholder value.');
    }
  }

  static const String _usage = r'''
Usage:
  fvm dart run benchmark/skeleton/validate_skeleton_benchmark_log.dart \
    --log <flutter-log> \
    --output-directory <artifact-directory> \
    --expected-run-id <fresh-run-id> \
    --expected-renderer <verified-renderer> \
    --expected-effect <fade|shimmer> \
    --expected-topology <single|many> \
    --expected-card-count <positive-integer> \
    --expected-warmup-frames <positive-integer> \
    --expected-frames-per-trial <positive-integer> \
    [--require-budget-pass] \
    [--require-enforced]
''';
}
