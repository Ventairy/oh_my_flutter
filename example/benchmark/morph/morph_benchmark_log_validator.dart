import 'dart:convert';

/// Validates the machine-readable records emitted by the Morph benchmark.
final class MorphBenchmarkLogValidator {
  /// Creates a validator for one exact benchmark workload.
  MorphBenchmarkLogValidator({
    required Iterable<String> expectedScenarioIds,
    this.minimumFrames = 150,
    this.requireBudgetPass = false,
    this.requireEnforcedBudget = false,
  }) : _expectedScenarioIds = List<String>.unmodifiable(expectedScenarioIds) {
    if (_expectedScenarioIds.isEmpty) {
      throw ArgumentError.value(
        expectedScenarioIds,
        'expectedScenarioIds',
        'must contain at least one scenario',
      );
    }
    if (_expectedScenarioIds.toSet().length != _expectedScenarioIds.length) {
      throw ArgumentError.value(
        expectedScenarioIds,
        'expectedScenarioIds',
        'must not contain duplicates',
      );
    }
    if (minimumFrames < 1) {
      throw ArgumentError.value(
        minimumFrames,
        'minimumFrames',
        'must be at least one',
      );
    }
  }

  static const _recordMarker = 'MORPH_BENCHMARK ';
  static const _chunkMarker = 'MORPH_BENCHMARK_CHUNK ';
  static const _expectedSteadyTrials = 2;
  static const _directions = <String>['forward', 'reverse'];

  final List<String> _expectedScenarioIds;

  /// Minimum number of attributed frames required in every steady gate.
  final int minimumFrames;

  /// Whether every steady gate must report that its work p99 fits the budget.
  final bool requireBudgetPass;

  /// Whether the application must have run with frame-budget enforcement.
  final bool requireEnforcedBudget;

  /// Parses and validates all Morph records found in [flutterLog].
  ///
  /// The returned JSON Lines string contains only successfully parsed benchmark
  /// records. The summary always describes invalid attempts and completed
  /// retries, even when the final acceptance result is valid.
  ({
    String extractedJsonLines,
    bool passed,
    String summary,
  })
  validate(String flutterLog) {
    final issues = <String>[];
    final records = <Map<String, Object?>>[];
    final chunkCounts = <int, int>{};
    final chunkPayloads = <int, List<String?>>{};
    var markedLineCount = 0;

    for (final line in const LineSplitter().convert(flutterLog)) {
      final chunkMarkerIndex = line.indexOf(_chunkMarker);
      if (chunkMarkerIndex >= 0) {
        markedLineCount += 1;
        final payloadStart = chunkMarkerIndex + _chunkMarker.length;
        final payload = line.substring(payloadStart).trim();
        _collectChunk(
          payload: payload,
          markedLineCount: markedLineCount,
          counts: chunkCounts,
          payloads: chunkPayloads,
          issues: issues,
        );
        continue;
      }
      final markerIndex = line.indexOf(_recordMarker);
      if (markerIndex < 0) continue;
      markedLineCount += 1;
      final payload = line.substring(markerIndex + _recordMarker.length).trim();
      try {
        final Object? decoded = jsonDecode(payload);
        if (decoded is! Map<String, Object?>) {
          issues.add('Record $markedLineCount is not a JSON object.');
          continue;
        }
        records.add(Map<String, Object?>.unmodifiable(decoded));
      } on FormatException catch (error) {
        issues.add(
          'Record $markedLineCount contains invalid JSON: ${error.message}.',
        );
      }
    }

    _decodeChunks(
      counts: chunkCounts,
      payloads: chunkPayloads,
      records: records,
      issues: issues,
    );

    if (markedLineCount == 0) {
      issues.add('The log contains no MORPH_BENCHMARK records.');
    }

    final environmentRecords = _recordsAtPath(records, 'environment');
    final acceptanceRecords = _recordsAtPath(records, 'acceptance');
    final errorRecords = _recordsAtPath(records, 'error');

    if (environmentRecords.length != 1) {
      issues.add(
        'Expected exactly one environment record; '
        'found ${environmentRecords.length}.',
      );
    }
    if (acceptanceRecords.length != 1) {
      issues.add(
        'Expected exactly one acceptance record; '
        'found ${acceptanceRecords.length}.',
      );
    }
    if (errorRecords.isNotEmpty) {
      final emittedErrors = errorRecords
          .map((record) {
            return record['error'] ?? 'unknown error';
          })
          .join('; ');
      issues.add(
        'The benchmark emitted ${errorRecords.length} error record(s): '
        '$emittedErrors.',
      );
    }

    Map<String, Object?>? environment;
    if (environmentRecords.length == 1) {
      environment = environmentRecords.single;
    }
    Map<String, Object?>? acceptance;
    if (acceptanceRecords.length == 1) {
      acceptance = acceptanceRecords.single;
    }
    _validateEnvironment(environment, issues);
    _validateSteadyGates(records, issues);
    _validateAcceptance(acceptance, issues);

    final invalidAttemptRecords = records
        .where((record) {
          return record['valid'] == false;
        })
        .toList(growable: false);
    final completedRetryRecords = records
        .where((record) {
          return record['retried'] == true;
        })
        .toList(growable: false);
    _validateRetryAccounting(
      invalidAttemptRecords: invalidAttemptRecords,
      completedRetryRecords: completedRetryRecords,
      acceptance: acceptance,
      issues: issues,
    );

    final extracted = records.map(jsonEncode).join('\n');
    final summary = _buildSummary(
      records: records,
      environment: environment,
      acceptance: acceptance,
      invalidAttemptRecords: invalidAttemptRecords,
      completedRetryRecords: completedRetryRecords,
      issues: issues,
    );
    return (
      extractedJsonLines: extracted.isEmpty ? '' : '$extracted\n',
      passed: issues.isEmpty,
      summary: summary,
    );
  }

  void _collectChunk({
    required String payload,
    required int markedLineCount,
    required Map<int, int> counts,
    required Map<int, List<String?>> payloads,
    required List<String> issues,
  }) {
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) {
        issues.add('Chunk $markedLineCount is not a JSON object.');
        return;
      }
      final record = decoded['record'];
      final index = decoded['index'];
      final count = decoded['count'];
      final chunkPayload = decoded['payload'];
      if (record is! int ||
          index is! int ||
          count is! int ||
          chunkPayload is! String ||
          count < 1 ||
          index < 0 ||
          index >= count) {
        issues.add('Chunk $markedLineCount has invalid metadata.');
        return;
      }
      final previousCount = counts[record];
      if (previousCount != null && previousCount != count) {
        issues.add('Chunked record $record has inconsistent counts.');
        return;
      }
      counts[record] = count;
      final parts = payloads.putIfAbsent(
        record,
        () => List<String?>.filled(count, null),
      );
      if (parts[index] != null) {
        issues.add('Chunked record $record repeats index $index.');
        return;
      }
      parts[index] = chunkPayload;
    } on FormatException catch (error) {
      issues.add(
        'Chunk $markedLineCount contains invalid JSON: ${error.message}.',
      );
    }
  }

  void _decodeChunks({
    required Map<int, int> counts,
    required Map<int, List<String?>> payloads,
    required List<Map<String, Object?>> records,
    required List<String> issues,
  }) {
    for (final entry in payloads.entries) {
      final record = entry.key;
      final parts = entry.value;
      if (parts.any((part) => part == null)) {
        final received = parts.whereType<String>().length;
        issues.add(
          'Chunked record $record is incomplete: '
          '$received/${counts[record]} chunks.',
        );
        continue;
      }
      try {
        final encoded = parts.cast<String>().join();
        final payload = utf8.decode(base64Decode(encoded));
        final Object? decoded = jsonDecode(payload);
        if (decoded is! Map<String, Object?>) {
          issues.add('Chunked record $record is not a JSON object.');
          continue;
        }
        records.add(Map<String, Object?>.unmodifiable(decoded));
      } on FormatException catch (error) {
        issues.add(
          'Chunked record $record has invalid payload: ${error.message}.',
        );
      }
    }
  }

  List<Map<String, Object?>> _recordsAtPath(
    List<Map<String, Object?>> records,
    String path,
  ) {
    return records
        .where((record) {
          return record['path'] == path;
        })
        .toList(growable: false);
  }

  void _validateEnvironment(
    Map<String, Object?>? environment,
    List<String> issues,
  ) {
    if (environment == null) return;

    if (environment['mode'] != 'profile') {
      issues.add(
        'Environment mode must be profile, got ${environment['mode']}.',
      );
    }
    final renderer = environment['renderer'];
    final rendererIsMissing = renderer is! String || renderer.trim().isEmpty;
    var rendererIsUnspecified = false;
    if (renderer is String) {
      rendererIsUnspecified = renderer.trim().toLowerCase() == 'unspecified';
    }
    if (rendererIsMissing || rendererIsUnspecified) {
      issues.add(
        'Environment renderer must be a verified, non-unspecified label.',
      );
    }
    final refreshRate = environment['refresh_rate_hz'];
    if (refreshRate is! num || !refreshRate.isFinite || refreshRate <= 0) {
      issues.add('Environment refresh_rate_hz must be finite and positive.');
    }

    final scenarioValues = environment['scenarios'];
    final actualScenarios = _stringList(scenarioValues);
    if (actualScenarios == null) {
      issues.add('Environment scenarios must be a list of strings.');
    } else {
      final distinctScenarios = actualScenarios.toSet();
      final duplicates = actualScenarios.length != distinctScenarios.length;
      final expectedSet = _expectedScenarioIds.toSet();
      final actualSet = distinctScenarios;
      var scenariosDiffer = actualSet.length != expectedSet.length;
      if (!scenariosDiffer) {
        scenariosDiffer = !actualSet.containsAll(expectedSet);
      }
      if (duplicates || scenariosDiffer) {
        issues.add(
          'Environment scenarios must exactly match '
          '${_expectedScenarioIds.join(', ')}; '
          'got ${actualScenarios.join(', ')}.',
        );
      }
    }

    if (environment['steady_trials'] != _expectedSteadyTrials) {
      issues.add(
        'Environment steady_trials must be $_expectedSteadyTrials; '
        'got ${environment['steady_trials']}.',
      );
    }
    final declaredFrames = environment['steady_frames_per_trial'];
    if (declaredFrames is! int || declaredFrames < minimumFrames) {
      issues.add(
        'Environment steady_frames_per_trial must be at least '
        '$minimumFrames; got $declaredFrames.',
      );
    }
  }

  void _validateSteadyGates(
    List<Map<String, Object?>> records,
    List<String> issues,
  ) {
    final expectedPaths = <String>{};
    for (final scenario in _expectedScenarioIds) {
      for (var trial = 1; trial <= _expectedSteadyTrials; trial += 1) {
        for (final direction in _directions) {
          final path = '$scenario.steady.$direction.trial_$trial';
          expectedPaths.add(path);
          final matches = records
              .where((record) {
                return record['path'] == path;
              })
              .toList(growable: false);
          if (matches.length != 1) {
            issues.add(
              'Expected exactly one steady gate at $path; '
              'found ${matches.length}.',
            );
            continue;
          }
          final result = matches.single;
          if (result['scenario'] != scenario ||
              result['phase'] != 'steady' ||
              result['direction'] != direction ||
              result['trial'] != trial) {
            issues.add('Steady result $path has inconsistent identity fields.');
          }
          if (result['gate'] != true) {
            issues.add('Steady result $path must set gate=true.');
          }
          final frames = result['frames'];
          if (frames is! int || frames < minimumFrames) {
            issues.add(
              'Steady result $path must contain at least '
              '$minimumFrames frames; got $frames.',
            );
          }
          if (requireBudgetPass && result['work_p99_within_budget'] != true) {
            issues.add(
              'Steady result $path did not pass its build/raster p99 budget.',
            );
          }
          final attempt = result['attempt'];
          if (attempt is! int || attempt < 1) {
            issues.add(
              'Steady result $path must contain a positive attempt number.',
            );
          }
          if (result['retried'] != (attempt is int && attempt > 1)) {
            issues.add(
              'Steady result $path has inconsistent '
              'attempt and retried fields.',
            );
          }
        }
      }
    }

    for (final record in records) {
      final scenario = record['scenario'];
      if (scenario is String && !_expectedScenarioIds.contains(scenario)) {
        issues.add(
          'Unexpected scenario $scenario at ${record['path'] ?? 'unknown'}.',
        );
      }
      if (record['phase'] != 'steady' || record['gate'] != true) continue;
      final path = record['path'];
      if (path is! String || !expectedPaths.contains(path)) {
        issues.add(
          'Unexpected steady gate record at ${path ?? 'an unknown path'}.',
        );
      }
    }
  }

  void _validateAcceptance(
    Map<String, Object?>? acceptance,
    List<String> issues,
  ) {
    if (acceptance == null) return;
    if (acceptance['passed'] != true) {
      issues.add('Application acceptance is not true.');
    }
    if (acceptance['steady_trials'] != _expectedSteadyTrials) {
      issues.add(
        'Acceptance steady_trials must be $_expectedSteadyTrials; '
        'got ${acceptance['steady_trials']}.',
      );
    }
    final acceptedFrames = acceptance['steady_frames_per_trial'];
    if (acceptedFrames is! int || acceptedFrames < minimumFrames) {
      issues.add(
        'Acceptance steady_frames_per_trial must be at least '
        '$minimumFrames; got $acceptedFrames.',
      );
    }
    final failedPaths = acceptance['failed_steady_paths'];
    if (failedPaths is! List<Object?> || failedPaths.isNotEmpty) {
      issues.add('Acceptance failed_steady_paths must be an empty list.');
    }
    if (requireEnforcedBudget && acceptance['enforced'] != true) {
      issues.add('Application frame-budget enforcement was not enabled.');
    }
  }

  void _validateRetryAccounting({
    required List<Map<String, Object?>> invalidAttemptRecords,
    required List<Map<String, Object?>> completedRetryRecords,
    required Map<String, Object?>? acceptance,
    required List<String> issues,
  }) {
    final retriedTrialIds = <String>{};
    for (final record in invalidAttemptRecords) {
      final attempt = record['attempt'];
      final reasons = _stringList(record['invalid_reasons']);
      if (attempt is! int || attempt < 1) {
        issues.add(
          'Invalid-attempt record ${record['path']} has no '
          'positive attempt number.',
        );
      }
      if (reasons == null || reasons.isEmpty) {
        issues.add(
          'Invalid-attempt record ${record['path']} has no invalid_reasons.',
        );
      }
      if (record['retrying'] != true) {
        issues.add(
          'Invalid-attempt record ${record['path']} did not schedule a retry.',
        );
      }
      if (attempt == 1 && record['retrying'] == true) {
        retriedTrialIds.add(
          '${record['scenario']}|${record['phase']}|${record['trial'] ?? 0}',
        );
      }
    }

    for (final record in completedRetryRecords) {
      final attempt = record['attempt'];
      if (attempt is! int || attempt <= 1 || record['retried'] != true) {
        issues.add(
          'Completed result ${record['path']} has inconsistent retry metadata.',
        );
      }
    }

    if (acceptance == null) return;
    final reportedInvalidAttempts = acceptance['invalid_trial_attempts'];
    if (reportedInvalidAttempts != invalidAttemptRecords.length) {
      issues.add(
        'Acceptance reports $reportedInvalidAttempts invalid attempts, '
        'but the log contains '
        '${invalidAttemptRecords.length}.',
      );
    }
    final reportedRetriedTrials = acceptance['retried_trials'];
    if (reportedRetriedTrials != retriedTrialIds.length) {
      issues.add(
        'Acceptance reports $reportedRetriedTrials retried trials, '
        'but the log contains '
        '${retriedTrialIds.length}.',
      );
    }
  }

  String _buildSummary({
    required List<Map<String, Object?>> records,
    required Map<String, Object?>? environment,
    required Map<String, Object?>? acceptance,
    required List<Map<String, Object?>> invalidAttemptRecords,
    required List<Map<String, Object?>> completedRetryRecords,
    required List<String> issues,
  }) {
    final steadyGateCount = records
        .where(
          (record) => record['phase'] == 'steady' && record['gate'] == true,
        )
        .length;
    final gatesPerScenario = _expectedSteadyTrials * _directions.length;
    final expectedGateCount = _expectedScenarioIds.length * gatesPerScenario;
    var workBudgetRequirement = 'reported only';
    if (requireBudgetPass) workBudgetRequirement = 'required';
    var enforcementRequirement = 'optional';
    if (requireEnforcedBudget) enforcementRequirement = 'required';
    final summary = StringBuffer()
      ..writeln(
        'Morph benchmark host validation: ${issues.isEmpty ? 'PASS' : 'FAIL'}',
      )
      ..writeln('Records: ${records.length}')
      ..writeln(
        'Environment: mode=${environment?['mode'] ?? 'missing'}; '
        'renderer=${environment?['renderer'] ?? 'missing'}; '
        'refresh_rate_hz=${environment?['refresh_rate_hz'] ?? 'missing'}',
      )
      ..writeln('Scenarios: ${_expectedScenarioIds.join(', ')}')
      ..writeln(
        'Steady gates: $steadyGateCount/$expectedGateCount; '
        'trials=$_expectedSteadyTrials; minimum_frames=$minimumFrames',
      )
      ..writeln(
        'Budget checks: work_p99=$workBudgetRequirement; '
        'application_enforcement=$enforcementRequirement',
      )
      ..writeln(
        'Acceptance: passed=${acceptance?['passed'] ?? 'missing'}; '
        'enforced=${acceptance?['enforced'] ?? 'missing'}',
      )
      ..writeln(
        'Invalid attempts: ${invalidAttemptRecords.length} '
        '(reported=${acceptance?['invalid_trial_attempts'] ?? 'missing'})',
      )
      ..writeln(
        'Completed retries: ${completedRetryRecords.length}; '
        'retried trials reported=${acceptance?['retried_trials'] ?? 'missing'}',
      );

    if (invalidAttemptRecords.isNotEmpty) {
      summary.writeln('Invalid attempt details:');
      for (final record in invalidAttemptRecords) {
        final reasons = _stringList(
          record['invalid_reasons'],
        )?.join(', ');
        summary.writeln(
          '- ${record['path']}: direction=${record['invalid_direction']}; '
          'reasons=${reasons ?? 'missing'}',
        );
      }
    }
    if (completedRetryRecords.isNotEmpty) {
      summary.writeln('Completed retry details:');
      for (final record in completedRetryRecords) {
        summary.writeln('- ${record['path']}: attempt=${record['attempt']}');
      }
    }
    if (issues.isNotEmpty) {
      summary.writeln('Validation issues:');
      for (final issue in issues) {
        summary.writeln('- $issue');
      }
    }
    return summary.toString();
  }

  List<String>? _stringList(Object? value) {
    if (value is! List<Object?>) return null;
    final values = <String>[];
    for (final item in value) {
      if (item is! String) return null;
      values.add(item);
    }
    return values;
  }
}
