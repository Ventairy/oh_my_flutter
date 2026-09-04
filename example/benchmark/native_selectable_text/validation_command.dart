import 'dart:io';

import 'log_validator.dart';
import 'scenario.dart';

/// Runs host-side validation for a NativeSelectableText benchmark log.
final class NativeSelectableTextBenchmarkValidationCommand {
  /// Creates the validation command.
  const NativeSelectableTextBenchmarkValidationCommand();

  static const String _artifactBaseName = 'native_selectable_text_benchmark';
  static const String _jsonLinesFileName = '$_artifactBaseName.jsonl';
  static const String _summaryFileName = '${_artifactBaseName}_summary.txt';

  /// Validates [arguments], writes artifacts, and returns a shell exit code.
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
      final validation = NativeSelectableTextBenchmarkLogValidator(
        expectedRunId: options.expectedRunId,
        expectedRenderer: options.expectedRenderer,
        expectedScenario: options.expectedScenario,
        expectedWidget: options.expectedWidget,
        expectedTextCase: options.expectedTextCase,
        expectedItemCount: options.expectedItemCount,
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
      final summaryFile = File(
        '${outputDirectory.path}/$_summaryFileName',
      );
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
          'NativeSelectableText benchmark validation could not run: $error',
        )
        ..writeln(_usage);
      return 1;
    }
  }

  ({
    int expectedFramesPerTrial,
    int expectedItemCount,
    String expectedRenderer,
    String expectedRunId,
    String expectedScenario,
    String expectedTextCase,
    int expectedWarmupFrames,
    String expectedWidget,
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
      '--expected-scenario',
      '--expected-widget',
      '--expected-text-case',
      '--expected-item-count',
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

    final missing = <String>[
      for (final option in valueOptions)
        if (!values.containsKey(option)) option,
    ];
    if (missing.isNotEmpty) {
      throw FormatException(
        'Missing required options: ${missing.join(', ')}.',
      );
    }

    final expectedRunId = values['--expected-run-id']!;
    final expectedRenderer = values['--expected-renderer']!;
    _requireNonPlaceholder(expectedRunId, '--expected-run-id');
    _requireNonPlaceholder(expectedRenderer, '--expected-renderer');
    final expectedScenario = values['--expected-scenario']!;
    if (!NativeSelectableTextBenchmarkScenario.accepts(expectedScenario)) {
      throw const FormatException(
        '--expected-scenario must be scroll, selection, or menu_idle.',
      );
    }
    final expectedWidget = values['--expected-widget']!;
    if (expectedWidget != 'native' && expectedWidget != 'selectable') {
      throw const FormatException(
        '--expected-widget must be native or selectable.',
      );
    }
    final expectedTextCase = values['--expected-text-case']!;
    if (!const <String>{
      'short',
      'paragraph',
      'long',
      'rich',
    }.contains(expectedTextCase)) {
      throw const FormatException(
        '--expected-text-case must be short, paragraph, long, or rich.',
      );
    }

    return (
      expectedFramesPerTrial: _positiveInteger(
        values['--expected-frames-per-trial']!,
        '--expected-frames-per-trial',
      ),
      expectedItemCount: _positiveInteger(
        values['--expected-item-count']!,
        '--expected-item-count',
      ),
      expectedRenderer: expectedRenderer,
      expectedRunId: expectedRunId,
      expectedScenario: expectedScenario,
      expectedTextCase: expectedTextCase,
      expectedWarmupFrames: _positiveInteger(
        values['--expected-warmup-frames']!,
        '--expected-warmup-frames',
      ),
      expectedWidget: expectedWidget,
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
  fvm dart run \
    benchmark/native_selectable_text/validate_native_selectable_text_benchmark_log.dart \
    --log <flutter-log> \
    --output-directory <artifact-directory> \
    --expected-run-id <fresh-run-id> \
    --expected-renderer <verified-renderer> \
    --expected-scenario <scroll|selection|menu_idle> \
    --expected-widget <native|selectable> \
    --expected-text-case <short|paragraph|long|rich> \
    --expected-item-count <positive-integer> \
    --expected-warmup-frames <positive-integer> \
    --expected-frames-per-trial <positive-integer> \
    [--require-budget-pass] \
    [--require-enforced]
''';
}
