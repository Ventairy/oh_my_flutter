import 'dart:convert';

import 'record_buffer.dart';
import 'scenario.dart';

/// Validates one captured NativeSelectableText benchmark process log.
final class NativeSelectableTextBenchmarkLogValidator {
  /// Creates a validator for one exact benchmark configuration.
  NativeSelectableTextBenchmarkLogValidator({
    required this.expectedRunId,
    required this.expectedRenderer,
    required this.expectedScenario,
    required this.expectedWidget,
    required this.expectedTextCase,
    required this.expectedItemCount,
    required this.expectedWarmupFrames,
    required this.expectedFramesPerTrial,
    this.requireBudgetPass = false,
    this.requireEnforcedBudget = false,
  }) {
    _requireNonPlaceholder(expectedRunId, 'expectedRunId');
    _requireNonPlaceholder(expectedRenderer, 'expectedRenderer');
    NativeSelectableTextBenchmarkScenario.parse(expectedScenario);
    if (expectedWidget != 'native' && expectedWidget != 'selectable') {
      throw ArgumentError.value(
        expectedWidget,
        'expectedWidget',
        'must be native or selectable',
      );
    }
    if (!const <String>{
      'short',
      'paragraph',
      'long',
      'rich',
    }.contains(expectedTextCase)) {
      throw ArgumentError.value(
        expectedTextCase,
        'expectedTextCase',
        'must be short, paragraph, long, or rich',
      );
    }
    _requirePositive(expectedItemCount, 'expectedItemCount');
    _requirePositive(expectedWarmupFrames, 'expectedWarmupFrames');
    _requirePositive(expectedFramesPerTrial, 'expectedFramesPerTrial');
  }

  static const int _expectedTrialCount = 2;

  /// Fresh identifier supplied to both the application and validator.
  final String expectedRunId;

  /// Renderer label independently confirmed in startup or device logs.
  final String expectedRenderer;

  /// Exact workload scenario selected for the process.
  final String expectedScenario;

  /// Exact selectable widget selected for the process.
  final String expectedWidget;

  /// Exact text-size or rich-text case selected for the process.
  final String expectedTextCase;

  /// Exact configured scroll item count.
  final int expectedItemCount;

  /// Exact warmup frames collected before each measured trial.
  final int expectedWarmupFrames;

  /// Exact attributed frames required in every measured trial.
  final int expectedFramesPerTrial;

  /// Whether both trials must fit their refresh-derived work budget.
  final bool requireBudgetPass;

  /// Whether application-side frame-budget enforcement must be enabled.
  final bool requireEnforcedBudget;

  /// Parses and validates all benchmark records in [flutterLog].
  ({String extractedJsonLines, bool passed, String summary}) validate(
    String flutterLog,
  ) {
    final issues = <String>[];
    final records = <Map<String, Object?>>[];
    final chunkCounts = <int, int>{};
    final chunkPayloads = <int, List<String?>>{};
    var markedLineCount = 0;
    const chunkMarker = NativeSelectableTextBenchmarkRecordBuffer.chunkMarker;
    const recordMarker = NativeSelectableTextBenchmarkRecordBuffer.recordMarker;

    for (final line in const LineSplitter().convert(flutterLog)) {
      final chunkIndex = line.indexOf(chunkMarker);
      if (chunkIndex >= 0) {
        markedLineCount += 1;
        _collectChunk(
          payload: line
              .substring(
                chunkIndex + chunkMarker.length,
              )
              .trim(),
          lineNumber: markedLineCount,
          counts: chunkCounts,
          payloads: chunkPayloads,
          issues: issues,
        );
        continue;
      }

      final recordIndex = line.indexOf(recordMarker);
      if (recordIndex < 0) continue;
      markedLineCount += 1;
      _decodeRecord(
        payload: line
            .substring(
              recordIndex + recordMarker.length,
            )
            .trim(),
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
      issues.add(
        'The log contains no NATIVE_SELECTABLE_TEXT_BENCHMARK records.',
      );
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
      final errors = errorRecords.map(_errorMessage).join('; ');
      issues.add(
        'The benchmark emitted ${errorRecords.length} error record(s): '
        '$errors.',
      );
    }

    _validateExactRecordSet(records, issues);
    _validateRunIds(records, issues);
    final environment = _singleRecord(environmentRecords);
    _validateEnvironment(environment, issues);

    final trialRecords = <Map<String, Object?>>[];
    final trialBudgetPasses = <int, bool>{};
    for (var trial = 1; trial <= _expectedTrialCount; trial += 1) {
      final matches = _recordsAtPath(records, 'trial.$trial');
      if (matches.length != 1) {
        issues.add(
          'Expected exactly one trial.$trial record; found ${matches.length}.',
        );
        continue;
      }
      final record = matches.single;
      trialRecords.add(record);
      trialBudgetPasses[trial] = _validateTrial(record, trial, issues);
    }

    final acceptance = _singleRecord(acceptanceRecords);
    _validateAcceptance(
      acceptance: acceptance,
      environment: environment,
      trialBudgetPasses: trialBudgetPasses,
      issues: issues,
    );

    final extracted = records.map(jsonEncode).join('\n');
    return (
      extractedJsonLines: extracted.isEmpty ? '' : '$extracted\n',
      passed: issues.isEmpty,
      summary: _buildSummary(
        records: records,
        environment: environment,
        acceptance: acceptance,
        trials: trialRecords,
        issues: issues,
      ),
    );
  }

  void _collectChunk({
    required String payload,
    required int lineNumber,
    required Map<int, int> counts,
    required Map<int, List<String?>> payloads,
    required List<String> issues,
  }) {
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) {
        issues.add('Chunk $lineNumber is not a JSON object.');
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
        issues.add('Chunk $lineNumber has invalid metadata.');
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
      if (parts.length != count) {
        issues.add('Chunked record $record has inconsistent storage.');
        return;
      }
      if (parts[index] != null) {
        issues.add('Chunked record $record repeats chunk $index.');
        return;
      }
      parts[index] = chunkPayload;
    } on FormatException catch (error) {
      issues.add('Chunk $lineNumber contains invalid JSON: ${error.message}.');
    }
  }

  void _decodeChunks({
    required Map<int, int> counts,
    required Map<int, List<String?>> payloads,
    required List<Map<String, Object?>> records,
    required List<String> issues,
  }) {
    final recordIds = counts.keys.toList()..sort();
    for (final recordId in recordIds) {
      final expectedCount = counts[recordId]!;
      final parts = payloads[recordId];
      final hasMissingPart = parts?.any((part) => part == null) ?? true;
      if (parts == null || parts.length != expectedCount || hasMissingPart) {
        issues.add('Chunked record $recordId is incomplete.');
        continue;
      }
      try {
        final encoded = parts.whereType<String>().join();
        final payload = utf8.decode(base64Decode(encoded));
        _decodeRecord(
          payload: payload,
          label: 'Chunked record $recordId',
          records: records,
          issues: issues,
        );
      } on FormatException catch (error) {
        issues.add(
          'Chunked record $recordId has invalid encoding: '
          '${error.message}.',
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
    const expectedPaths = <String>{
      'environment',
      'trial.1',
      'trial.2',
      'acceptance',
      'error',
    };
    for (final record in records) {
      final path = record['path'];
      if (path is! String || path.isEmpty) {
        issues.add('Every benchmark record must contain a non-empty path.');
      } else if (!expectedPaths.contains(path)) {
        issues.add('Unexpected benchmark record at $path.');
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
          'Record ${record['path']} has run_id=${record['run_id']}; '
          'expected $expectedRunId.',
        );
      }
    }
  }

  void _validateEnvironment(
    Map<String, Object?>? record,
    List<String> issues,
  ) {
    if (record == null) return;
    _expectEqual(record, 'mode', 'profile', 'Environment', issues);
    _expectEqual(
      record,
      'renderer',
      expectedRenderer,
      'Environment',
      issues,
    );
    _expectEqual(
      record,
      'scenario',
      expectedScenario,
      'Environment',
      issues,
    );
    _expectEqual(
      record,
      'widget',
      expectedWidget,
      'Environment',
      issues,
    );
    _expectEqual(
      record,
      'text_case',
      expectedTextCase,
      'Environment',
      issues,
    );
    _expectEqual(
      record,
      'warmup_frames',
      expectedWarmupFrames,
      'Environment',
      issues,
    );
    _expectEqual(
      record,
      'measured_frames',
      expectedFramesPerTrial,
      'Environment',
      issues,
    );
    _expectEqual(
      record,
      'trials',
      _expectedTrialCount,
      'Environment',
      issues,
    );
    _expectEqual(
      record,
      'configured_item_count',
      expectedItemCount,
      'Environment',
      issues,
    );
    var activeWidgetCount = 1;
    if (expectedScenario == 'scroll') {
      activeWidgetCount = expectedItemCount;
    }
    _expectEqual(
      record,
      'active_widget_count',
      activeWidgetCount,
      'Environment',
      issues,
    );

    for (final field in const <String>[
      'platform',
      'operating_system',
      'renderer_source',
    ]) {
      final value = record[field];
      if (value is! String || value.trim().isEmpty) {
        issues.add('Environment $field must be a non-empty string.');
      }
    }
    final refreshRate = record['refresh_rate_hz'];
    final budget = record['frame_budget_us'];
    if (!_isPositiveFiniteNumber(refreshRate)) {
      issues.add('Environment refresh_rate_hz must be finite and positive.');
    } else {
      final hertz = refreshRate! as num;
      final frameDuration = Duration.microsecondsPerSecond / hertz;
      final expectedBudget = frameDuration.floor();
      if (budget != expectedBudget) {
        issues.add(
          'Environment frame_budget_us must be $expectedBudget for '
          'refresh_rate_hz=$refreshRate; got $budget.',
        );
      }
    }
    if (budget is! int || budget < 1) {
      issues.add('Environment frame_budget_us must be a positive integer.');
    }
    _validateSize(record['logical_size'], 'logical_size', issues);
    _validateSize(record['physical_size'], 'physical_size', issues);
    if (!_isPositiveFiniteNumber(record['device_pixel_ratio'])) {
      issues.add('Environment device_pixel_ratio must be positive.');
    }
    final textCodeUnits = record['text_code_units'];
    if (textCodeUnits is! int || textCodeUnits < 3) {
      issues.add('Environment text_code_units must be at least three.');
    }
    final inlineSpanCount = record['inline_span_count'];
    final validSpanCount = expectedTextCase == 'rich'
        ? inlineSpanCount is int && inlineSpanCount > 1
        : inlineSpanCount == 1;
    if (!validSpanCount) {
      issues.add(
        'Environment inline_span_count=$inlineSpanCount is invalid for '
        'text_case=$expectedTextCase.',
      );
    }
    if (record['frame_budget_enforced'] is! bool) {
      issues.add('Environment frame_budget_enforced must be a boolean.');
    }
  }

  bool _validateTrial(
    Map<String, Object?> record,
    int expectedTrial,
    List<String> issues,
  ) {
    final label = 'Trial $expectedTrial';
    _expectEqual(record, 'trial', expectedTrial, label, issues);
    _expectEqual(record, 'valid', true, label, issues);
    _expectEqual(record, 'gate', true, label, issues);
    _expectEqual(record, 'scenario', expectedScenario, label, issues);
    _expectEqual(record, 'widget', expectedWidget, label, issues);
    _expectEqual(record, 'text_case', expectedTextCase, label, issues);
    _expectEqual(
      record,
      'frames',
      expectedFramesPerTrial,
      label,
      issues,
    );
    final budget = record['frame_budget_us'];
    if (budget is! int || budget < 1) {
      issues.add('$label frame_budget_us must be a positive integer.');
      return false;
    }
    final buildP99 = _validateStatistics(
      record['build'],
      '$label build',
      issues,
    );
    final rasterP99 = _validateStatistics(
      record['raster'],
      '$label raster',
      issues,
    );
    _validateStatistics(record['total_span'], '$label total_span', issues);
    _validateStatistics(
      record['vsync_overhead'],
      '$label vsync_overhead',
      issues,
    );

    for (final field in const <String>[
      'build_over_budget',
      'raster_over_budget',
      'total_span_over_budget',
      'vsync_over_budget',
      'work_over_budget',
      'any_over_budget',
      'longest_work_miss_streak',
      'longest_any_miss_streak',
    ]) {
      final value = record[field];
      if (value is! int || value < 0 || value > expectedFramesPerTrial) {
        issues.add(
          '$label $field must be between zero and '
          '$expectedFramesPerTrial; got $value.',
        );
      }
    }
    final buildMisses = record['build_over_budget'];
    final rasterMisses = record['raster_over_budget'];
    final totalMisses = record['total_span_over_budget'];
    final vsyncMisses = record['vsync_over_budget'];
    final workMisses = record['work_over_budget'];
    final anyMisses = record['any_over_budget'];
    if (workMisses is int) {
      final belowBuild = buildMisses is int && workMisses < buildMisses;
      final belowRaster = rasterMisses is int && workMisses < rasterMisses;
      var aboveSum = false;
      if (buildMisses is int && rasterMisses is int) {
        aboveSum = workMisses > buildMisses + rasterMisses;
      }
      if (belowBuild || belowRaster || aboveSum) {
        issues.add('$label has inconsistent work-over-budget counts.');
      }
    }
    if (anyMisses is int &&
        <Object?>[
          workMisses,
          totalMisses,
          vsyncMisses,
        ].whereType<int>().any((count) => count > anyMisses)) {
      issues.add('$label has inconsistent any-over-budget count.');
    }
    final longestWork = record['longest_work_miss_streak'];
    final longestAny = record['longest_any_miss_streak'];
    if (longestWork is int && workMisses is int && longestWork > workMisses) {
      issues.add('$label longest work miss streak exceeds its miss count.');
    }
    if (longestAny is int && anyMisses is int && longestAny > anyMisses) {
      issues.add('$label longest any miss streak exceeds its miss count.');
    }

    final buildPass = buildP99 != null && buildP99 <= budget;
    final rasterPass = rasterP99 != null && rasterP99 <= budget;
    final computedPass = buildPass && rasterPass;
    if (record['work_p99_within_budget'] != computedPass) {
      issues.add('$label has inconsistent work_p99_within_budget.');
    }
    return computedPass;
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
    final statistics = <num>[];
    for (final field in const <String>[
      'p50_us',
      'p90_us',
      'p99_us',
      'max_us',
      'mean_us',
    ]) {
      final statistic = value[field];
      if (statistic is! num || !statistic.isFinite || statistic < 0) {
        issues.add('$label has invalid $field=$statistic.');
        return null;
      }
      statistics.add(statistic);
    }
    final p50ExceedsP90 = statistics[0] > statistics[1];
    final p90ExceedsP99 = statistics[1] > statistics[2];
    final p99ExceedsMaximum = statistics[2] > statistics[3];
    if (p50ExceedsP90 || p90ExceedsP99 || p99ExceedsMaximum) {
      issues.add('$label percentile statistics are not monotonic.');
    }
    if (statistics[4] > statistics[3]) {
      issues.add('$label mean_us exceeds max_us.');
    }
    return statistics[2];
  }

  void _validateAcceptance({
    required Map<String, Object?>? acceptance,
    required Map<String, Object?>? environment,
    required Map<int, bool> trialBudgetPasses,
    required List<String> issues,
  }) {
    if (acceptance == null) return;
    _expectEqual(
      acceptance,
      'scenario',
      expectedScenario,
      'Acceptance',
      issues,
    );
    _expectEqual(
      acceptance,
      'widget',
      expectedWidget,
      'Acceptance',
      issues,
    );
    _expectEqual(
      acceptance,
      'text_case',
      expectedTextCase,
      'Acceptance',
      issues,
    );
    _expectEqual(
      acceptance,
      'trials',
      _expectedTrialCount,
      'Acceptance',
      issues,
    );
    _expectEqual(
      acceptance,
      'frames_per_trial',
      expectedFramesPerTrial,
      'Acceptance',
      issues,
    );

    final expectedFailedPaths = <String>[
      for (var trial = 1; trial <= _expectedTrialCount; trial += 1)
        if (trialBudgetPasses[trial] == false) 'trial.$trial',
    ];
    final failedPaths = _stringList(acceptance['failed_trial_paths']);
    if (failedPaths == null ||
        failedPaths.length != expectedFailedPaths.length ||
        !failedPaths.toSet().containsAll(expectedFailedPaths)) {
      issues.add(
        'Acceptance failed_trial_paths must be $expectedFailedPaths; '
        'got ${acceptance['failed_trial_paths']}.',
      );
    }
    final allTrialsPresent = trialBudgetPasses.length == _expectedTrialCount;
    final computedPass = allTrialsPresent && expectedFailedPaths.isEmpty;
    if (acceptance['passed'] != computedPass) {
      issues.add(
        'Acceptance passed must be $computedPass; '
        'got ${acceptance['passed']}.',
      );
    }
    if (acceptance['enforced'] is! bool) {
      issues.add('Acceptance enforced must be a boolean.');
    }
    final environmentEnforcement = environment?['frame_budget_enforced'];
    final acceptanceEnforcement = acceptance['enforced'];
    if (environment != null) {
      if (environmentEnforcement != acceptanceEnforcement) {
        issues.add('Environment and acceptance enforcement disagree.');
      }
    }
    if (requireBudgetPass && !computedPass) {
      issues.add('The measured trials did not pass the frame-budget gate.');
    }
    if (requireEnforcedBudget && acceptance['enforced'] != true) {
      issues.add('Application-side frame-budget enforcement was not enabled.');
    }
  }

  void _validateSize(
    Object? value,
    String label,
    List<String> issues,
  ) {
    if (value is! Map<String, Object?>) {
      issues.add('Environment $label must be a JSON object.');
      return;
    }
    for (final dimension in const <String>['width', 'height']) {
      if (!_isPositiveFiniteNumber(value[dimension])) {
        issues.add('Environment $label.$dimension must be positive.');
      }
    }
  }

  String _buildSummary({
    required List<Map<String, Object?>> records,
    required Map<String, Object?>? environment,
    required Map<String, Object?>? acceptance,
    required List<Map<String, Object?>> trials,
    required List<String> issues,
  }) {
    final summary = StringBuffer()
      ..writeln(
        'NativeSelectableText benchmark host validation: '
        '${issues.isEmpty ? 'PASS' : 'FAIL'}',
      )
      ..writeln('Run ID: $expectedRunId')
      ..writeln('Records: ${records.length}')
      ..writeln(
        'Configuration: scenario=$expectedScenario; widget=$expectedWidget; '
        'text_case=$expectedTextCase; renderer=$expectedRenderer',
      )
      ..writeln(
        'Display: refresh_rate_hz='
        '${environment?['refresh_rate_hz'] ?? 'missing'}; '
        'frame_budget_us=${environment?['frame_budget_us'] ?? 'missing'}',
      )
      ..writeln(
        'Trials: ${trials.length}/$_expectedTrialCount; '
        'frames_per_trial=$expectedFramesPerTrial; '
        'warmup_frames=$expectedWarmupFrames',
      )
      ..writeln(
        'Acceptance: passed=${acceptance?['passed'] ?? 'missing'}; '
        'enforced=${acceptance?['enforced'] ?? 'missing'}; '
        'failed=${acceptance?['failed_trial_paths'] ?? 'missing'}',
      );
    for (final trial in trials) {
      summary.writeln(
        '${trial['path']}: build_p99_us='
        '${_statistic(trial['build'], 'p99_us')}; '
        'raster_p99_us=${_statistic(trial['raster'], 'p99_us')}; '
        'work_misses=${trial['work_over_budget']}; '
        'longest_work_streak=${trial['longest_work_miss_streak']}',
      );
    }
    if (issues.isNotEmpty) {
      summary.writeln('Validation issues:');
      for (final issue in issues) {
        summary.writeln('- $issue');
      }
    }
    return summary.toString();
  }

  Object _statistic(Object? value, String field) {
    if (value is! Map<String, Object?>) return 'missing';
    return value[field] ?? 'missing';
  }

  Object _errorMessage(Map<String, Object?> record) {
    return record['error'] ?? 'unknown error';
  }

  List<Map<String, Object?>> _recordsAtPath(
    List<Map<String, Object?>> records,
    String path,
  ) {
    return List<Map<String, Object?>>.unmodifiable(
      records.where((record) => record['path'] == path),
    );
  }

  Map<String, Object?>? _singleRecord(
    List<Map<String, Object?>> records,
  ) {
    return records.length == 1 ? records.single : null;
  }

  void _expectEqual(
    Map<String, Object?> record,
    String field,
    Object expected,
    String label,
    List<String> issues,
  ) {
    if (record[field] != expected) {
      issues.add('$label $field must be $expected; got ${record[field]}.');
    }
  }

  List<String>? _stringList(Object? value) {
    if (value is! List<Object?>) return null;
    final result = <String>[];
    for (final element in value) {
      if (element is! String) return null;
      result.add(element);
    }
    return result;
  }

  bool _isPositiveFiniteNumber(Object? value) {
    return value is num && value.isFinite && value > 0;
  }

  static void _requireNonPlaceholder(String value, String name) {
    if (value.trim().isEmpty || value.trim().toLowerCase() == 'unspecified') {
      throw ArgumentError.value(value, name, 'must not be a placeholder');
    }
  }

  static void _requirePositive(int value, String name) {
    if (value < 1) {
      throw ArgumentError.value(value, name, 'must be positive');
    }
  }
}
