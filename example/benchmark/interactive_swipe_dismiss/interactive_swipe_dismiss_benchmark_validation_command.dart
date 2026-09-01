import 'dart:io';

import 'interactive_swipe_dismiss_benchmark_log_validator.dart';

/// Runs host-side validation for a captured swipe benchmark log.
final class InteractiveSwipeDismissBenchmarkValidationCommand {
  /// Creates the validation command.
  const InteractiveSwipeDismissBenchmarkValidationCommand();

  static const String _fileNamePrefix = 'interactive_swipe_dismiss_benchmark';
  static const String _jsonLinesFileName = '$_fileNamePrefix.jsonl';
  static const String _summaryFileName = '${_fileNamePrefix}_summary.txt';

  /// Validates [arguments], writes artifacts, and returns a process exit code.
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
      final validation = InteractiveSwipeDismissBenchmarkLogValidator(
        expectedRunId: options.expectedRunId,
        expectedRenderer: options.expectedRenderer,
        expectedWarmupFrames: options.expectedWarmupFrames,
        expectedFramesPerTrial: options.expectedFramesPerTrial,
        requireBudgetPass: options.requireBudgetPass,
        requireEnforcedBudget: options.requireEnforcedBudget,
        requireRetainedPaint: options.requireRetainedPaint,
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
        ..writeln(
          'InteractiveSwipeDismiss benchmark log validation could not run: '
          '$error',
        )
        ..writeln(_usage);
      return 1;
    }
  }

  ({
    int expectedFramesPerTrial,
    String expectedRenderer,
    String expectedRunId,
    int expectedWarmupFrames,
    String logPath,
    String outputDirectory,
    bool requireBudgetPass,
    bool requireEnforcedBudget,
    bool requireRetainedPaint,
  })
  _parse(List<String> arguments) {
    final values = <String, String>{};
    final flags = <String>{};
    const valueOptions = <String>{
      '--log',
      '--output-directory',
      '--expected-run-id',
      '--expected-renderer',
      '--expected-warmup-frames',
      '--expected-frames-per-trial',
    };
    const flagOptions = <String>{
      '--require-budget-pass',
      '--require-enforced',
      '--require-retained-paint',
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
    _requireNonPlaceholder(
      values['--expected-run-id']!,
      '--expected-run-id',
    );
    _requireNonPlaceholder(
      values['--expected-renderer']!,
      '--expected-renderer',
    );
    return (
      expectedFramesPerTrial: _integerAtLeastTwo(
        values['--expected-frames-per-trial']!,
        '--expected-frames-per-trial',
      ),
      expectedRenderer: values['--expected-renderer']!,
      expectedRunId: values['--expected-run-id']!,
      expectedWarmupFrames: _integerAtLeastTwo(
        values['--expected-warmup-frames']!,
        '--expected-warmup-frames',
      ),
      logPath: values['--log']!,
      outputDirectory: values['--output-directory']!,
      requireBudgetPass: flags.contains('--require-budget-pass'),
      requireEnforcedBudget: flags.contains('--require-enforced'),
      requireRetainedPaint: flags.contains('--require-retained-paint'),
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

  int _integerAtLeastTwo(String value, String option) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 2) {
      throw FormatException('$option must be an integer of at least two.');
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
  fvm dart run \
    benchmark/interactive_swipe_dismiss/validate_interactive_swipe_dismiss_benchmark_log.dart \
    --log <flutter-log> \
    --output-directory <artifact-directory> \
    --expected-run-id <fresh-run-id> \
    --expected-renderer <verified-renderer> \
    --expected-warmup-frames <integer-at-least-two> \
    --expected-frames-per-trial <integer-at-least-two> \
    [--require-budget-pass] \
    [--require-enforced] \
    [--require-retained-paint]
''';
}
