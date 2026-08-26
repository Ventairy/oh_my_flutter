import 'dart:convert';

/// Validates the machine-readable records emitted by the Skeleton benchmark.
final class SkeletonBenchmarkLogValidator {
  /// Creates a validator for one exact Skeleton benchmark workload.
  SkeletonBenchmarkLogValidator({
    required this.expectedRunId,
    required this.expectedRenderer,
    required this.expectedEffect,
    required this.expectedTopology,
    required this.expectedCardCount,
    required this.expectedWarmupFrames,
    required this.expectedFramesPerTrial,
    this.requireBudgetPass = false,
    this.requireEnforcedBudget = false,
  }) {
    _requireNonPlaceholder(expectedRunId, 'expectedRunId');
    _requireNonPlaceholder(expectedRenderer, 'expectedRenderer');
    if (expectedEffect != 'fade' && expectedEffect != 'shimmer') {
      throw ArgumentError.value(
        expectedEffect,
        'expectedEffect',
        'must be fade or shimmer',
      );
    }
    if (expectedTopology != 'single' && expectedTopology != 'many') {
      throw ArgumentError.value(
        expectedTopology,
        'expectedTopology',
        'must be single or many',
      );
    }
    if (expectedCardCount < 1) {
      throw ArgumentError.value(
        expectedCardCount,
        'expectedCardCount',
        'must be at least one',
      );
    }
    if (expectedWarmupFrames < 1) {
      throw ArgumentError.value(
        expectedWarmupFrames,
        'expectedWarmupFrames',
        'must be at least one',
      );
    }
    if (expectedFramesPerTrial < 1) {
      throw ArgumentError.value(
        expectedFramesPerTrial,
        'expectedFramesPerTrial',
        'must be at least one',
      );
    }
  }

  static const String _recordMarker = 'SKELETON_BENCHMARK ';
  static const String _chunkMarker = 'SKELETON_BENCHMARK_CHUNK ';
  static const int _expectedSteadyTrials = 2;
  static const int _maximumTrialAttempts = 3;
  static final RegExp _invalidAttemptPath = RegExp(
    r'^steady\.trial_([12])\.invalid\.attempt_([1-3])$',
  );

  /// Fresh identifier supplied to both the application and validator.
  final String expectedRunId;

  /// Renderer label verified independently in device logs.
  final String expectedRenderer;

  /// Effect selected for this process.
  final String expectedEffect;

  /// Skeleton ownership topology selected for this process.
  final String expectedTopology;

  /// Exact number of cards selected for this process.
  final int expectedCardCount;

  /// Exact warmup frame count before each steady trial.
  final int expectedWarmupFrames;

  /// Exact attributed frame count required in each steady trial.
  final int expectedFramesPerTrial;

  /// Whether both steady gates must report build/raster p99 within budget.
  final bool requireBudgetPass;

  /// Whether application-side frame-budget enforcement must be enabled.
  final bool requireEnforcedBudget;

  /// Parses and validates all Skeleton records found in [flutterLog].
  ({String extractedJsonLines, bool passed, String summary}) validate(
    String flutterLog,
  ) {
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
      _decodeRecord(
        payload: payload,
        label: 'Record $markedLineCount',
        records: records,
        issues: issues,
      );
    }

    _decodeChunks(
      counts: chunkCounts,
      payloads: chunkPayloads,
      records: records,
      issues: issues,
    );
    if (markedLineCount == 0) {
      issues.add('The log contains no SKELETON_BENCHMARK records.');
    }

    final environmentRecords = _recordsAtPath(records, 'environment');
    final acceptanceRecords = _recordsAtPath(records, 'acceptance');
    final errorRecords = _recordsAtPath(records, 'error');
    final steadyRecords = <Map<String, Object?>>[];
    for (var trial = 1; trial <= _expectedSteadyTrials; trial += 1) {
      final matches = _recordsAtPath(records, 'steady.trial_$trial');
      if (matches.length != 1) {
        issues.add(
          'Expected exactly one steady gate at steady.trial_$trial; '
          'found ${matches.length}.',
        );
      } else {
        steadyRecords.add(matches.single);
      }
    }

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
      final errors = errorRecords.map(_errorMessage).join('; ');
      issues.add(
        'The benchmark emitted ${errorRecords.length} error record(s): '
        '$errors.',
      );
    }

    _validateExactRecordSet(records, issues);
    _validateRunIds(records, issues);
    final environment = _singleRecord(environmentRecords);
    final acceptance = _singleRecord(acceptanceRecords);
    _validateEnvironment(environment, issues);
    for (final record in steadyRecords) {
      _validateSteadyGate(record, issues);
    }
    final invalidAttemptRecords = records
        .where((record) {
          final path = record['path'];
          return path is String && _invalidAttemptPath.hasMatch(path);
        })
        .toList(growable: false);
    _validateRetries(
      steadyRecords: steadyRecords,
      invalidAttemptRecords: invalidAttemptRecords,
      issues: issues,
    );
    _validateAcceptance(
      acceptance: acceptance,
      invalidAttemptRecords: invalidAttemptRecords,
      steadyRecords: steadyRecords,
      issues: issues,
    );

    final extracted = records.map(jsonEncode).join('\n');
    final summary = _buildSummary(
      records: records,
      environment: environment,
      acceptance: acceptance,
      invalidAttemptRecords: invalidAttemptRecords,
      steadyRecords: steadyRecords,
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
        final payload = utf8.decode(
          base64Decode(parts.cast<String>().join()),
        );
        _decodeRecord(
          payload: payload,
          label: 'Chunked record $record',
          records: records,
          issues: issues,
        );
      } on FormatException catch (error) {
        issues.add(
          'Chunked record $record has invalid payload: ${error.message}.',
        );
      }
    }
  }

  void _decodeRecord({
    required String payload,
    required String label,
    required List<Map<String, Object?>> records,
    required List<String> issues,
  }) {
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) {
        issues.add('$label is not a JSON object.');
        return;
      }
      records.add(Map<String, Object?>.unmodifiable(decoded));
    } on FormatException catch (error) {
      issues.add('$label contains invalid JSON: ${error.message}.');
    }
  }

  void _validateExactRecordSet(
    List<Map<String, Object?>> records,
    List<String> issues,
  ) {
    const fixedPaths = <String>{
      'environment',
      'steady.trial_1',
      'steady.trial_2',
      'acceptance',
      'error',
    };
    final pathCounts = <String, int>{};
    for (final record in records) {
      final path = record['path'];
      if (path is! String || path.isEmpty) {
        issues.add('Every benchmark record must contain a non-empty path.');
        continue;
      }
      pathCounts.update(path, (count) => count + 1, ifAbsent: () => 1);
      if (!fixedPaths.contains(path) && !_invalidAttemptPath.hasMatch(path)) {
        issues.add('Unexpected benchmark record at $path.');
      }
    }
    for (final entry in pathCounts.entries) {
      if (entry.value > 1) {
        issues.add(
          'Expected record path ${entry.key} at most once; '
          'found ${entry.value}.',
        );
      }
    }
  }

  void _validateRunIds(
    List<Map<String, Object?>> records,
    List<String> issues,
  ) {
    for (final record in records) {
      if (record['run_id'] != expectedRunId) {
        issues.add(
          'Record ${record['path'] ?? 'unknown'} must use run_id '
          '$expectedRunId; got ${record['run_id']}.',
        );
      }
    }
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
    _expectEqual(
      record: environment,
      field: 'renderer',
      expected: expectedRenderer,
      label: 'Environment',
      issues: issues,
    );
    _expectEqual(
      record: environment,
      field: 'effect',
      expected: expectedEffect,
      label: 'Environment',
      issues: issues,
    );
    _expectEqual(
      record: environment,
      field: 'topology',
      expected: expectedTopology,
      label: 'Environment',
      issues: issues,
    );
    _expectEqual(
      record: environment,
      field: 'card_count',
      expected: expectedCardCount,
      label: 'Environment',
      issues: issues,
    );
    _expectEqual(
      record: environment,
      field: 'warmup_frames_per_trial',
      expected: expectedWarmupFrames,
      label: 'Environment',
      issues: issues,
    );
    _expectEqual(
      record: environment,
      field: 'steady_trials',
      expected: _expectedSteadyTrials,
      label: 'Environment',
      issues: issues,
    );
    _expectEqual(
      record: environment,
      field: 'steady_frames_per_trial',
      expected: expectedFramesPerTrial,
      label: 'Environment',
      issues: issues,
    );
    _expectEqual(
      record: environment,
      field: 'maximum_trial_attempts',
      expected: _maximumTrialAttempts,
      label: 'Environment',
      issues: issues,
    );
    final refreshRate = environment['refresh_rate_hz'];
    final budget = environment['frame_budget_us'];
    if (refreshRate is! num || !refreshRate.isFinite || refreshRate <= 0) {
      issues.add('Environment refresh_rate_hz must be finite and positive.');
    } else {
      final frameDuration = Duration.microsecondsPerSecond / refreshRate;
      final expectedBudget = frameDuration.floor();
      if (budget != expectedBudget) {
        issues.add(
          'Environment frame_budget_us must be $expectedBudget for '
          '$refreshRate Hz; got $budget.',
        );
      }
    }
    _validatePositiveSize(
      environment['logical_size'],
      'Environment logical_size',
      issues,
    );
    _validatePositiveSize(
      environment['physical_size'],
      'Environment physical_size',
      issues,
    );
    final devicePixelRatio = environment['device_pixel_ratio'];
    final devicePixelRatioIsValid = _isPositiveFiniteNumber(
      devicePixelRatio,
    );
    if (!devicePixelRatioIsValid) {
      issues.add(
        'Environment device_pixel_ratio must be finite and positive.',
      );
    }
    if (environment['animations_disabled'] != false) {
      issues.add(
        'Environment animations_disabled must be false for an animated '
        'Skeleton benchmark.',
      );
    }
  }

  void _validatePositiveSize(
    Object? value,
    String label,
    List<String> issues,
  ) {
    if (value is! Map<String, Object?>) {
      issues.add('$label must be a JSON object.');
      return;
    }
    for (final dimension in const <String>['width', 'height']) {
      final extent = value[dimension];
      if (!_isPositiveFiniteNumber(extent)) {
        issues.add('$label $dimension must be finite and positive.');
      }
    }
  }

  bool _isPositiveFiniteNumber(Object? value) {
    if (value is! num) return false;
    return value.isFinite && value > 0;
  }

  void _validateSteadyGate(
    Map<String, Object?> record,
    List<String> issues,
  ) {
    final trial = record['trial'];
    final path = record['path'];
    if (trial is! int || trial < 1 || trial > _expectedSteadyTrials) {
      issues.add('Steady record $path has invalid trial $trial.');
      return;
    }
    if (path != 'steady.trial_$trial' ||
        record['phase'] != 'steady' ||
        record['valid'] != true ||
        record['gate'] != true) {
      issues.add('Steady record $path has inconsistent identity fields.');
    }
    _expectEqual(
      record: record,
      field: 'effect',
      expected: expectedEffect,
      label: 'Steady record $path',
      issues: issues,
    );
    _expectEqual(
      record: record,
      field: 'topology',
      expected: expectedTopology,
      label: 'Steady record $path',
      issues: issues,
    );
    _expectEqual(
      record: record,
      field: 'frames',
      expected: expectedFramesPerTrial,
      label: 'Steady record $path',
      issues: issues,
    );
    final attempt = record['attempt'];
    if (attempt is! int || attempt < 1 || attempt > _maximumTrialAttempts) {
      issues.add('Steady record $path has invalid attempt $attempt.');
    }
    if (record['retried'] != (attempt is int && attempt > 1)) {
      issues.add('Steady record $path has inconsistent retry metadata.');
    }
    final budget = record['frame_budget_us'];
    if (budget is! int || budget < 1) {
      issues.add('Steady record $path has invalid frame_budget_us $budget.');
      return;
    }
    final buildP99 = _validateStatistics(
      record['build'],
      '$path build',
      issues,
    );
    final rasterP99 = _validateStatistics(
      record['raster'],
      '$path raster',
      issues,
    );
    _validateStatistics(record['total_span'], '$path total_span', issues);
    _validateStatistics(
      record['vsync_overhead'],
      '$path vsync_overhead',
      issues,
    );
    final hasStatistics = buildP99 != null && rasterP99 != null;
    final buildPasses = buildP99 != null && buildP99 <= budget;
    final rasterPasses = rasterP99 != null && rasterP99 <= budget;
    final computedBudgetPass = hasStatistics && buildPasses && rasterPasses;
    if (record['work_p99_within_budget'] != computedBudgetPass) {
      issues.add(
        'Steady record $path has inconsistent work_p99_within_budget.',
      );
    }
    if (requireBudgetPass && !computedBudgetPass) {
      issues.add('Steady record $path did not pass its build/raster p99 gate.');
    }
    final probePaints = record['probe_paints'];
    final transientCallbacks = record['transient_callbacks'];
    final computedStructuralPass = probePaints == 0 && transientCallbacks == 1;
    if (record['structural_invariants_passed'] != computedStructuralPass) {
      issues.add(
        'Steady record $path has inconsistent '
        'structural_invariants_passed.',
      );
    }
    if (!computedStructuralPass) {
      issues.add(
        'Steady record $path must retain descendants with probe_paints=0 '
        'and use exactly one transient callback; got '
        'probe_paints=$probePaints and '
        'transient_callbacks=$transientCallbacks.',
      );
    }
    for (final field in const <String>[
      'probe_paints',
      'transient_callbacks',
      'build_over_budget',
      'raster_over_budget',
      'total_span_over_budget',
      'any_over_budget',
      'longest_consecutive_misses',
    ]) {
      final value = record[field];
      if (value is! int || value < 0) {
        issues.add('Steady record $path has invalid $field $value.');
      }
    }
    for (final field in const <String>[
      'build_over_budget',
      'raster_over_budget',
      'total_span_over_budget',
      'any_over_budget',
      'longest_consecutive_misses',
    ]) {
      final value = record[field];
      if (value is int && value > expectedFramesPerTrial) {
        issues.add(
          'Steady record $path has $field=$value above its frame count.',
        );
      }
    }
  }

  num? _validateStatistics(
    Object? value,
    String label,
    List<String> issues,
  ) {
    if (value is! Map<String, Object?>) {
      issues.add('$label statistics must be a JSON object.');
      return null;
    }
    final fields = <num>[];
    for (final field in const <String>[
      'p50_us',
      'p90_us',
      'p99_us',
      'max_us',
      'mean_us',
    ]) {
      final statistic = value[field];
      if (statistic is! num || !statistic.isFinite || statistic < 0) {
        issues.add('$label has invalid $field $statistic.');
        return null;
      }
      fields.add(statistic);
    }
    final p50ExceedsP90 = fields[0] > fields[1];
    final p90ExceedsP99 = fields[1] > fields[2];
    final p99ExceedsMaximum = fields[2] > fields[3];
    if (p50ExceedsP90 || p90ExceedsP99 || p99ExceedsMaximum) {
      issues.add('$label percentile statistics are not monotonic.');
    }
    return fields[2];
  }

  void _validateRetries({
    required List<Map<String, Object?>> steadyRecords,
    required List<Map<String, Object?>> invalidAttemptRecords,
    required List<String> issues,
  }) {
    for (final invalid in invalidAttemptRecords) {
      final path = invalid['path'];
      RegExpMatch? match;
      if (path is String) match = _invalidAttemptPath.firstMatch(path);
      final trial = invalid['trial'];
      final attempt = invalid['attempt'];
      if (match == null ||
          trial != int.parse(match.group(1)!) ||
          attempt != int.parse(match.group(2)!) ||
          invalid['phase'] != 'steady' ||
          invalid['valid'] != false) {
        issues.add('Invalid-attempt record $path has inconsistent identity.');
      }
      final reasons = _stringList(invalid['invalid_reasons']);
      if (reasons == null || reasons.isEmpty) {
        issues.add('Invalid-attempt record $path has no invalid_reasons.');
      }
      final frames = invalid['collected_frames'];
      if (frames is! int || frames < 0 || frames > expectedFramesPerTrial) {
        issues.add('Invalid-attempt record $path has invalid frame count.');
      }
      final retryWasScheduled = invalid['retrying'] == true;
      final maximumAttempts = invalid['maximum_trial_attempts'];
      final attemptsMatch = maximumAttempts == _maximumTrialAttempts;
      if (!retryWasScheduled || !attemptsMatch) {
        issues.add('Invalid-attempt record $path did not declare its retry.');
      }
    }

    for (final steady in steadyRecords) {
      final trial = steady['trial'];
      final successfulAttempt = steady['attempt'];
      if (trial is! int || successfulAttempt is! int) continue;
      final actualAttempts = invalidAttemptRecords
          .where((record) => record['trial'] == trial)
          .map((record) => record['attempt'])
          .whereType<int>()
          .toSet();
      final expectedAttempts = <int>{};
      for (var attempt = 1; attempt < successfulAttempt; attempt += 1) {
        expectedAttempts.add(attempt);
      }
      final countsMatch = actualAttempts.length == expectedAttempts.length;
      final attemptsMatch = actualAttempts.containsAll(expectedAttempts);
      if (!countsMatch || !attemptsMatch) {
        issues.add(
          'Steady trial $trial completed at attempt $successfulAttempt but '
          'its invalid attempts were ${actualAttempts.toList()..sort()}.',
        );
      }
    }
  }

  void _validateAcceptance({
    required Map<String, Object?>? acceptance,
    required List<Map<String, Object?>> invalidAttemptRecords,
    required List<Map<String, Object?>> steadyRecords,
    required List<String> issues,
  }) {
    if (acceptance == null) return;
    if (acceptance['passed'] != true) {
      issues.add('Application acceptance is not true.');
    }
    _expectEqual(
      record: acceptance,
      field: 'steady_trials',
      expected: _expectedSteadyTrials,
      label: 'Acceptance',
      issues: issues,
    );
    _expectEqual(
      record: acceptance,
      field: 'steady_frames_per_trial',
      expected: expectedFramesPerTrial,
      label: 'Acceptance',
      issues: issues,
    );
    _expectEqual(
      record: acceptance,
      field: 'maximum_trial_attempts',
      expected: _maximumTrialAttempts,
      label: 'Acceptance',
      issues: issues,
    );
    final failedPaths = acceptance['failed_steady_paths'];
    if (failedPaths is! List<Object?> || failedPaths.isNotEmpty) {
      issues.add('Acceptance failed_steady_paths must be an empty list.');
    }
    if (requireEnforcedBudget && acceptance['enforced'] != true) {
      issues.add('Application frame-budget enforcement was not enabled.');
    }
    _expectEqual(
      record: acceptance,
      field: 'invalid_trial_attempts',
      expected: invalidAttemptRecords.length,
      label: 'Acceptance',
      issues: issues,
    );
    final retriedTrials = _retriedTrialCount(steadyRecords);
    _expectEqual(
      record: acceptance,
      field: 'retried_trials',
      expected: retriedTrials,
      label: 'Acceptance',
      issues: issues,
    );
  }

  String _buildSummary({
    required List<Map<String, Object?>> records,
    required Map<String, Object?>? environment,
    required Map<String, Object?>? acceptance,
    required List<Map<String, Object?>> invalidAttemptRecords,
    required List<Map<String, Object?>> steadyRecords,
    required List<String> issues,
  }) {
    final summary = StringBuffer()
      ..writeln(
        'Skeleton benchmark host validation: '
        '${issues.isEmpty ? 'PASS' : 'FAIL'}',
      )
      ..writeln('Run ID: $expectedRunId')
      ..writeln('Records: ${records.length}')
      ..writeln(
        'Environment: mode=${environment?['mode'] ?? 'missing'}; '
        'renderer=${environment?['renderer'] ?? 'missing'}; '
        'refresh_rate_hz=${environment?['refresh_rate_hz'] ?? 'missing'}',
      )
      ..writeln(
        'View: logical_size=${environment?['logical_size'] ?? 'missing'}; '
        'physical_size=${environment?['physical_size'] ?? 'missing'}; '
        'dpr=${environment?['device_pixel_ratio'] ?? 'missing'}',
      )
      ..writeln(
        'Workload: effect=$expectedEffect; topology=$expectedTopology; '
        'cards=$expectedCardCount',
      )
      ..writeln(
        'Steady gates: ${steadyRecords.length}/$_expectedSteadyTrials; '
        'frames_per_trial=$expectedFramesPerTrial; '
        'warmup_frames=$expectedWarmupFrames',
      )
      ..writeln(
        'Acceptance: passed=${acceptance?['passed'] ?? 'missing'}; '
        'enforced=${acceptance?['enforced'] ?? 'missing'}',
      )
      ..writeln(
        'Invalid attempts: ${invalidAttemptRecords.length}; '
        'retried trials='
        '${_retriedTrialCount(steadyRecords)}',
      );
    if (invalidAttemptRecords.isNotEmpty) {
      summary.writeln('Invalid attempt details:');
      for (final record in invalidAttemptRecords) {
        summary.writeln(
          '- ${record['path']}: '
          '${_stringList(record['invalid_reasons'])?.join(', ') ?? 'missing'}',
        );
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

  List<Map<String, Object?>> _recordsAtPath(
    List<Map<String, Object?>> records,
    String path,
  ) {
    final matches = <Map<String, Object?>>[];
    for (final record in records) {
      if (record['path'] == path) matches.add(record);
    }
    return List<Map<String, Object?>>.unmodifiable(matches);
  }

  Map<String, Object?>? _singleRecord(
    List<Map<String, Object?>> records,
  ) {
    if (records.length != 1) return null;
    return records.single;
  }

  Object _errorMessage(Map<String, Object?> record) {
    return record['error'] ?? 'unknown error';
  }

  int _retriedTrialCount(List<Map<String, Object?>> records) {
    var count = 0;
    for (final record in records) {
      if (record['retried'] == true) count += 1;
    }
    return count;
  }

  void _expectEqual({
    required Map<String, Object?> record,
    required String field,
    required Object expected,
    required String label,
    required List<String> issues,
  }) {
    if (record[field] != expected) {
      issues.add(
        '$label $field must be $expected; got ${record[field]}.',
      );
    }
  }

  List<String>? _stringList(Object? value) {
    if (value is! List<Object?>) return null;
    final strings = <String>[];
    for (final item in value) {
      if (item is! String) return null;
      strings.add(item);
    }
    return strings;
  }

  static void _requireNonPlaceholder(String value, String name) {
    if (value.trim().isEmpty || value.trim().toLowerCase() == 'unspecified') {
      throw ArgumentError.value(value, name, 'must be a non-placeholder value');
    }
  }
}
