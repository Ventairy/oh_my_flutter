import 'dart:io';

import 'morph_benchmark_log_validator.dart';
import 'morph_benchmark_scenario.dart';

/// Runs host-side validation for a captured Morph benchmark log.
final class MorphBenchmarkValidationCommand {
  /// Creates the Morph benchmark validation command.
  const MorphBenchmarkValidationCommand();

  static const _jsonLinesFileName = 'morph_benchmark.jsonl';
  static const _summaryFileName = 'morph_benchmark_summary.txt';

  /// Validates [arguments], writes validation artifacts, and returns a process
  /// exit code.
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
      final validator = MorphBenchmarkLogValidator(
        expectedScenarioIds: options.expectedScenarioIds,
        minimumFrames: options.minimumFrames,
        requireBudgetPass: options.requireBudgetPass,
        requireEnforcedBudget: options.requireEnforcedBudget,
      );
      final validation = validator.validate(log);
      final outputDirectory = Directory(options.outputDirectory);
      await outputDirectory.create(recursive: true);
      final jsonLinesFile = File('${outputDirectory.path}/$_jsonLinesFileName');
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
        ..writeln('Morph benchmark log validation could not run: $error')
        ..writeln(_usage);
      return 1;
    }
  }

  ({
    List<String> expectedScenarioIds,
    String logPath,
    int minimumFrames,
    String outputDirectory,
    bool requireBudgetPass,
    bool requireEnforcedBudget,
  })
  _parse(List<String> arguments) {
    String? logPath;
    String? outputDirectory;
    String? expectedScenarios;
    var minimumFrames = 150;
    var requireBudgetPass = false;
    var requireEnforcedBudget = false;

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      switch (argument) {
        case '--log':
          logPath = _followingValue(arguments, ++index, argument);
        case '--output-directory':
          outputDirectory = _followingValue(arguments, ++index, argument);
        case '--expected-scenarios':
          expectedScenarios = _followingValue(arguments, ++index, argument);
        case '--minimum-frames':
          final value = _followingValue(arguments, ++index, argument);
          minimumFrames = int.tryParse(value) ?? -1;
        case '--require-budget-pass':
          requireBudgetPass = true;
        case '--require-enforced':
          requireEnforcedBudget = true;
        default:
          throw FormatException('Unknown argument: $argument');
      }
    }

    if (logPath == null) {
      throw const FormatException(
        '--log, --output-directory, and --expected-scenarios are required.',
      );
    }
    if (outputDirectory == null) {
      throw const FormatException(
        '--log, --output-directory, and --expected-scenarios are required.',
      );
    }
    if (expectedScenarios == null) {
      throw const FormatException(
        '--log, --output-directory, and --expected-scenarios are required.',
      );
    }
    if (minimumFrames < 1) {
      throw const FormatException('--minimum-frames must be at least one.');
    }

    late final List<String> scenarioIds;
    if (expectedScenarios == 'all') {
      scenarioIds = MorphBenchmarkScenario.values
          .map((scenario) {
            return scenario.id;
          })
          .toList(growable: false);
    } else {
      scenarioIds = expectedScenarios
          .split(',')
          .map((value) {
            return value.trim();
          })
          .toList(growable: false);
    }
    var scenarioListIsInvalid = scenarioIds.isEmpty;
    if (!scenarioListIsInvalid) {
      scenarioListIsInvalid = scenarioIds.any((scenario) => scenario.isEmpty);
    }
    if (scenarioListIsInvalid) {
      throw const FormatException('--expected-scenarios must not be empty.');
    }
    if (scenarioIds.toSet().length != scenarioIds.length) {
      throw const FormatException(
        '--expected-scenarios must not contain duplicates.',
      );
    }
    scenarioIds.forEach(MorphBenchmarkScenario.fromId);

    return (
      expectedScenarioIds: scenarioIds,
      logPath: logPath,
      minimumFrames: minimumFrames,
      outputDirectory: outputDirectory,
      requireBudgetPass: requireBudgetPass,
      requireEnforcedBudget: requireEnforcedBudget,
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

  static const _usage = r'''
Usage:
  fvm dart run benchmark/morph/validate_morph_benchmark_log.dart \
    --log <flutter-log> \
    --output-directory <artifact-directory> \
    --expected-scenarios <all|comma-separated-ids> \
    [--minimum-frames 150] \
    [--require-budget-pass] \
    [--require-enforced]
''';
}
