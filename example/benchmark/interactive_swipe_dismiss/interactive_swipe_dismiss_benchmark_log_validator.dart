import 'dart:convert';
import 'dart:math' as math;

import 'interactive_swipe_dismiss_benchmark_record_buffer.dart';

/// Validates the machine-readable InteractiveSwipeDismiss benchmark records.
final class InteractiveSwipeDismissBenchmarkLogValidator {
  /// Creates a validator for one exact benchmark run.
  InteractiveSwipeDismissBenchmarkLogValidator({
    required this.expectedRunId,
    required this.expectedRenderer,
    required this.expectedWarmupFrames,
    required this.expectedFramesPerTrial,
    this.requireBudgetPass = false,
    this.requireEnforcedBudget = false,
    this.requireRetainedPaint = false,
  }) {
    _requireNonPlaceholder(expectedRunId, 'expectedRunId');
    _requireNonPlaceholder(expectedRenderer, 'expectedRenderer');
    if (expectedWarmupFrames < 2) {
      throw ArgumentError.value(
        expectedWarmupFrames,
        'expectedWarmupFrames',
        'must be at least two',
      );
    }
    if (expectedFramesPerTrial < 2) {
      throw ArgumentError.value(
        expectedFramesPerTrial,
        'expectedFramesPerTrial',
        'must be at least two',
      );
    }
  }

  static const String _scenario = 'cataqui_scrolled_header_free_drag';
  static const int _expectedSteadyTrials = 2;
  static const int _maximumTrialAttempts = 3;
  static const int _heavyRowCount = 80;
  static const double _initialScrollOffset = 600;
  static const double _scrollTolerance = 0.01;
  static const double _sensitivity = 0.37;
  static const double _dismissThreshold = 0.25;
  static final RegExp _invalidAttemptPath = RegExp(
    r'^steady\.trial_([12])\.invalid\.attempt_([1-3])$',
  );

  /// Fresh identifier supplied to both the application and validator.
  final String expectedRunId;

  /// Renderer label verified independently in startup or device logs.
  final String expectedRenderer;

  /// Exact warmup frame count used before each trial.
  final int expectedWarmupFrames;

  /// Exact measured frame count required in each trial.
  final int expectedFramesPerTrial;

  /// Whether both trial p99 build/raster gates must fit the frame budget.
  final bool requireBudgetPass;

  /// Whether application-side frame-budget enforcement must be enabled.
  final bool requireEnforcedBudget;

  /// Whether every measured drag must retain descendant paint output.
  final bool requireRetainedPaint;

  /// Parses and validates all benchmark records in [flutterLog].
  ({String extractedJsonLines, bool passed, String summary}) validate(
    String flutterLog,
  ) {
    final issues = <String>[];
    final records = <Map<String, Object?>>[];
    final chunkCounts = <int, int>{};
    final chunkPayloads = <int, List<String?>>{};
    var markedLineCount = 0;

    for (final line in const LineSplitter().convert(flutterLog)) {
      final chunkMarkerIndex = line.indexOf(
        InteractiveSwipeDismissBenchmarkRecordBuffer.chunkMarker,
      );
      if (chunkMarkerIndex >= 0) {
        markedLineCount += 1;
        // The configured formatter keeps this fully qualified marker
        // expression on one line.
        // ignore: lines_longer_than_80_chars
        final payloadStart = chunkMarkerIndex + InteractiveSwipeDismissBenchmarkRecordBuffer.chunkMarker.length;
        _collectChunk(
          payload: line.substring(payloadStart).trim(),
          markedLineCount: markedLineCount,
          counts: chunkCounts,
          payloads: chunkPayloads,
          issues: issues,
        );
        continue;
      }
      final markerIndex = line.indexOf(
        InteractiveSwipeDismissBenchmarkRecordBuffer.recordMarker,
      );
      if (markerIndex < 0) continue;
      markedLineCount += 1;
      // The configured formatter keeps this fully qualified marker expression
      // on one line.
      // ignore: lines_longer_than_80_chars
      final payloadStart = markerIndex + InteractiveSwipeDismissBenchmarkRecordBuffer.recordMarker.length;
      _decodeRecord(
        payload: line.substring(payloadStart).trim(),
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
        'The log contains no INTERACTIVE_SWIPE_DISMISS_BENCHMARK records.',
      );
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
    final expectedEnvironment = _validateEnvironment(
      environment,
      issues,
    );
    final failedSteadyPaths = <String>[];
    for (final record in steadyRecords) {
      if (!_validateSteadyGate(
        record,
        expectedDismissDistance: expectedEnvironment?.dismissDistance,
        expectedFrameBudget: expectedEnvironment?.frameBudget,
        expectedMaximumRawPrimary: expectedEnvironment?.maximumRawPrimary,
        issues: issues,
      )) {
        final path = record['path'];
        if (path is String) failedSteadyPaths.add(path);
      }
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
      failedSteadyPaths: failedSteadyPaths,
      invalidAttemptRecords: invalidAttemptRecords,
      steadyRecords: steadyRecords,
      issues: issues,
    );

    final extracted = records.map(jsonEncode).join('\n');
    final summary = _buildSummary(
      environment: environment,
      acceptance: acceptance,
      steadyRecords: steadyRecords,
      invalidAttemptRecords: invalidAttemptRecords,
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
      if (parts.length != count) {
        issues.add('Chunked record $record has inconsistent storage.');
        return;
      }
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

  ({
    double dismissDistance,
    int frameBudget,
    double maximumRawPrimary,
  })?
  _validateEnvironment(
    Map<String, Object?>? environment,
    List<String> issues,
  ) {
    if (environment == null) return null;
    _expectEqual(
      record: environment,
      field: 'mode',
      expected: 'profile',
      label: 'Environment',
      issues: issues,
    );
    _expectEqual(
      record: environment,
      field: 'renderer',
      expected: expectedRenderer,
      label: 'Environment',
      issues: issues,
    );
    for (final entry in <String, Object>{
      'scenario': _scenario,
      'direction': 'down',
      'free_drag': true,
      'sensitivity': _sensitivity,
      'dismiss_threshold': _dismissThreshold,
      'initial_scroll_offset_px': _initialScrollOffset,
      'heavy_row_count': _heavyRowCount,
      'gesture_driver': 'synthetic_touch_one_move_per_vsync',
      'animations_disabled': false,
      'preflight_passed': true,
      'require_retained_paint': requireRetainedPaint,
      'warmup_frames_per_trial': expectedWarmupFrames,
      'steady_trials': _expectedSteadyTrials,
      'steady_frames_per_trial': expectedFramesPerTrial,
      'maximum_trial_attempts': _maximumTrialAttempts,
    }.entries) {
      _expectEqual(
        record: environment,
        field: entry.key,
        expected: entry.value,
        label: 'Environment',
        issues: issues,
      );
    }

    final refreshRate = environment['refresh_rate_hz'];
    final budget = environment['frame_budget_us'];
    int? expectedBudget;
    if (refreshRate is! num || !refreshRate.isFinite || refreshRate <= 0) {
      issues.add('Environment refresh_rate_hz must be finite and positive.');
    } else {
      expectedBudget = (Duration.microsecondsPerSecond / refreshRate).floor();
      if (budget != expectedBudget) {
        issues.add(
          'Environment frame_budget_us must be $expectedBudget for '
          '$refreshRate Hz; got $budget.',
        );
      }
    }
    final logicalHeight = _validatePositiveSize(
      environment['logical_size'],
      'Environment logical_size',
      issues,
    );
    _validatePositiveSize(
      environment['physical_size'],
      'Environment physical_size',
      issues,
    );
    if (!_isPositiveFiniteNumber(environment['device_pixel_ratio'])) {
      issues.add(
        'Environment device_pixel_ratio must be finite and positive.',
      );
    }
    if (logicalHeight == null || expectedBudget == null) return null;
    return (
      dismissDistance: logicalHeight * _dismissThreshold,
      frameBudget: expectedBudget,
      maximumRawPrimary: math.min(120, logicalHeight * 0.18),
    );
  }

  double? _validatePositiveSize(
    Object? value,
    String label,
    List<String> issues,
  ) {
    if (value is! Map<String, Object?>) {
      issues.add('$label must be a JSON object.');
      return null;
    }
    double? height;
    for (final dimension in const <String>['width', 'height']) {
      final extent = value[dimension];
      if (!_isPositiveFiniteNumber(extent)) {
        issues.add('$label $dimension must be finite and positive.');
      } else if (dimension == 'height') {
        height = (extent! as num).toDouble();
      }
    }
    return height;
  }

  bool _validateSteadyGate(
    Map<String, Object?> record, {
    required double? expectedDismissDistance,
    required int? expectedFrameBudget,
    required double? expectedMaximumRawPrimary,
    required List<String> issues,
  }) {
    final issueCountBefore = issues.length;
    final trial = record['trial'];
    final path = record['path'];
    if (trial is! int || trial < 1 || trial > _expectedSteadyTrials) {
      issues.add('Steady record $path has invalid trial $trial.');
      return false;
    }
    for (final entry in <String, Object>{
      'path': 'steady.trial_$trial',
      'scenario': _scenario,
      'phase': 'steady',
      'trial': trial,
      'valid': true,
      'gate': true,
      'frames': expectedFramesPerTrial,
      'pointer_moves': expectedFramesPerTrial,
      'retained_paint_required': requireRetainedPaint,
    }.entries) {
      _expectEqual(
        record: record,
        field: entry.key,
        expected: entry.value,
        label: 'Steady record $path',
        issues: issues,
      );
    }
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
      return false;
    }
    if (expectedFrameBudget != null && budget != expectedFrameBudget) {
      issues.add(
        'Steady record $path frame_budget_us must match the environment '
        'budget $expectedFrameBudget; got $budget.',
      );
    }

    final rawTimings = record['frame_timings_us'];
    Map<String, Object?>? timingMap;
    if (rawTimings is Map<String, Object?>) {
      timingMap = rawTimings;
    } else {
      issues.add('Steady record $path frame_timings_us must be an object.');
    }
    final build = _validateDistribution(
      raw: timingMap?['build'],
      reportedStatistics: record['build'],
      label: '$path build',
      expectedLength: expectedFramesPerTrial,
      issues: issues,
    );
    final raster = _validateDistribution(
      raw: timingMap?['raster'],
      reportedStatistics: record['raster'],
      label: '$path raster',
      expectedLength: expectedFramesPerTrial,
      issues: issues,
    );
    final totalSpan = _validateDistribution(
      raw: timingMap?['total_span'],
      reportedStatistics: record['total_span'],
      label: '$path total_span',
      expectedLength: expectedFramesPerTrial,
      issues: issues,
    );
    _validateDistribution(
      raw: timingMap?['vsync_overhead'],
      reportedStatistics: record['vsync_overhead'],
      label: '$path vsync_overhead',
      expectedLength: expectedFramesPerTrial,
      issues: issues,
    );
    final dispatch = _validateDistribution(
      raw: record['dispatch_durations_us'],
      reportedStatistics: record['dispatch'],
      label: '$path dispatch',
      expectedLength: expectedFramesPerTrial,
      issues: issues,
    );

    final buildPass = build != null && _percentile(build, 0.99) <= budget;
    final rasterPass = raster != null && _percentile(raster, 0.99) <= budget;
    final workPass = buildPass && rasterPass;
    if (record['work_p99_within_budget'] != workPass) {
      issues.add(
        'Steady record $path has inconsistent work_p99_within_budget.',
      );
    }
    if (requireBudgetPass && !workPass) {
      issues.add(
        'Steady record $path did not pass its build/raster p99 gate.',
      );
    }

    if (build != null && raster != null && totalSpan != null) {
      final computedBudgetMetrics = _budgetMetrics(
        build: build,
        raster: raster,
        totalSpan: totalSpan,
        budget: budget,
      );
      for (final entry in computedBudgetMetrics.entries) {
        _expectEqual(
          record: record,
          field: entry.key,
          expected: entry.value,
          label: 'Steady record $path',
          issues: issues,
        );
      }
    }

    final probeBuilds = record['probe_builds'];
    final probeLayouts = record['probe_layouts'];
    final probePaints = record['probe_paints'];
    final scrollStart = record['scroll_start_px'];
    final scrollEnd = record['scroll_end_px'];
    final maximumScrollDrift = record['maximum_scroll_drift_px'];
    final dismissCallbacks = record['dismiss_callbacks'];
    final maximumTransientCallbacks = record['maximum_transient_callbacks'];
    final maximumRawPrimary = record['maximum_raw_primary_px'];
    final dismissDistance = record['dismiss_distance_px'];
    final scrollIsStable =
        _sameNumber(scrollStart, _initialScrollOffset) &&
        _sameNumber(scrollEnd, _initialScrollOffset) &&
        maximumScrollDrift is num &&
        maximumScrollDrift.isFinite &&
        maximumScrollDrift >= 0 &&
        maximumScrollDrift <= _scrollTolerance;
    final dismissalDistanceIsValid =
        maximumRawPrimary is num &&
        maximumRawPrimary.isFinite &&
        maximumRawPrimary > 0 &&
        expectedMaximumRawPrimary != null &&
        _sameNumber(maximumRawPrimary, expectedMaximumRawPrimary) &&
        dismissDistance is num &&
        dismissDistance.isFinite &&
        expectedDismissDistance != null &&
        _sameNumber(dismissDistance, expectedDismissDistance) &&
        maximumRawPrimary < dismissDistance;
    final probePaintsIsValid =
        probePaints is int &&
        probePaints >= 0 &&
        probePaints <= expectedFramesPerTrial &&
        (!requireRetainedPaint || probePaints == 0);
    final structuralPass =
        dispatch != null &&
        probeBuilds == 0 &&
        probeLayouts == 0 &&
        probePaintsIsValid &&
        scrollIsStable &&
        dismissCallbacks == 0 &&
        maximumTransientCallbacks is int &&
        maximumTransientCallbacks >= 0 &&
        maximumTransientCallbacks <= 1 &&
        dismissalDistanceIsValid;
    if (record['structural_invariants_passed'] != structuralPass) {
      issues.add(
        'Steady record $path has inconsistent '
        'structural_invariants_passed.',
      );
    }
    if (!structuralPass) {
      issues.add(
        'Steady record $path failed child-build, child-layout, scroll-freeze, '
        'callback, or below-threshold invariants.',
      );
    }
    return workPass && structuralPass && issues.length == issueCountBefore;
  }

  List<int>? _validateDistribution({
    required Object? raw,
    required Object? reportedStatistics,
    required String label,
    required int expectedLength,
    required List<String> issues,
  }) {
    if (raw is! List<Object?>) {
      issues.add('$label raw distribution must be a JSON array.');
      return null;
    }
    final hasExpectedLength = raw.length == expectedLength;
    if (!hasExpectedLength) {
      issues.add(
        '$label raw distribution must contain $expectedLength values; '
        'got ${raw.length}.',
      );
    }
    final values = <int>[];
    for (final value in raw) {
      if (value is! int || value < 0) {
        issues.add('$label raw distribution contains invalid value $value.');
        return null;
      }
      values.add(value);
    }
    if (values.isEmpty) {
      issues.add('$label raw distribution must not be empty.');
      return null;
    }
    final expected = _summarize(values);
    if (reportedStatistics is! Map<String, Object?>) {
      issues.add('$label statistics must be a JSON object.');
      return hasExpectedLength ? values : null;
    }
    for (final entry in expected.entries) {
      if (!_sameNumber(reportedStatistics[entry.key], entry.value)) {
        issues.add(
          '$label ${entry.key} must be ${entry.value}; '
          'got ${reportedStatistics[entry.key]}.',
        );
      }
    }
    if (reportedStatistics.length != expected.length) {
      issues.add('$label statistics contain unexpected fields.');
    }
    return hasExpectedLength ? values : null;
  }

  Map<String, int> _budgetMetrics({
    required List<int> build,
    required List<int> raster,
    required List<int> totalSpan,
    required int budget,
  }) {
    var buildOverBudget = 0;
    var rasterOverBudget = 0;
    var totalSpanOverBudget = 0;
    var anyOverBudget = 0;
    var consecutiveMisses = 0;
    var longestConsecutiveMisses = 0;
    for (var index = 0; index < build.length; index += 1) {
      final buildMissed = build[index] > budget;
      final rasterMissed = raster[index] > budget;
      final totalSpanMissed = totalSpan[index] > budget;
      if (buildMissed) buildOverBudget += 1;
      if (rasterMissed) rasterOverBudget += 1;
      if (totalSpanMissed) totalSpanOverBudget += 1;
      if (buildMissed || rasterMissed || totalSpanMissed) {
        anyOverBudget += 1;
        consecutiveMisses += 1;
        longestConsecutiveMisses = math.max(
          longestConsecutiveMisses,
          consecutiveMisses,
        );
      } else {
        consecutiveMisses = 0;
      }
    }
    return <String, int>{
      'build_over_budget': buildOverBudget,
      'raster_over_budget': rasterOverBudget,
      'total_span_over_budget': totalSpanOverBudget,
      'any_over_budget': anyOverBudget,
      'longest_consecutive_misses': longestConsecutiveMisses,
    };
  }

  void _validateRetries({
    required List<Map<String, Object?>> steadyRecords,
    required List<Map<String, Object?>> invalidAttemptRecords,
    required List<String> issues,
  }) {
    for (var trial = 1; trial <= _expectedSteadyTrials; trial += 1) {
      final invalidForTrial = invalidAttemptRecords
          .where((record) {
            return record['trial'] == trial;
          })
          .toList(growable: false);
      for (final record in invalidForTrial) {
        final attempt = record['attempt'];
        var attemptIsInvalid = attempt is! int;
        if (attempt is int) {
          attemptIsInvalid = attempt < 1 || attempt >= _maximumTrialAttempts;
        }
        if (attemptIsInvalid) {
          issues.add(
            'Invalid attempt record ${record['path']} has invalid attempt '
            '$attempt.',
          );
        }
      }
      invalidForTrial.sort((first, second) {
        final firstAttempt = first['attempt'];
        final secondAttempt = second['attempt'];
        if (firstAttempt is! int || secondAttempt is! int) return 0;
        return firstAttempt.compareTo(secondAttempt);
      });
      for (var index = 0; index < invalidForTrial.length; index += 1) {
        final record = invalidForTrial[index];
        final attempt = index + 1;
        final path = 'steady.trial_$trial.invalid.attempt_$attempt';
        if (record['path'] != path ||
            record['phase'] != 'steady' ||
            record['attempt'] != attempt ||
            record['valid'] != false ||
            record['retrying'] != true ||
            record['maximum_trial_attempts'] != _maximumTrialAttempts) {
          issues.add(
            'Invalid attempt record $path has inconsistent metadata.',
          );
        }
        final reasons = record['invalid_reasons'];
        if (reasons is! List<Object?> ||
            reasons.isEmpty ||
            reasons.any((reason) => reason is! String || reason.isEmpty)) {
          issues.add('Invalid attempt record $path must name its reasons.');
        }
        for (final field in const <String>[
          'collected_frames',
          'pointer_moves',
        ]) {
          final value = record[field];
          if (value is! int || value < 0 || value > expectedFramesPerTrial) {
            issues.add(
              'Invalid attempt record $path has invalid $field $value.',
            );
          }
        }
      }
      final matchingSteady = steadyRecords.where(
        (record) => record['trial'] == trial,
      );
      final steady = matchingSteady.isEmpty ? null : matchingSteady.first;
      if (steady != null && steady['attempt'] != invalidForTrial.length + 1) {
        issues.add(
          'Steady trial $trial attempt must follow its invalid attempts.',
        );
      }
    }
  }

  void _validateAcceptance({
    required Map<String, Object?>? acceptance,
    required List<String> failedSteadyPaths,
    required List<Map<String, Object?>> invalidAttemptRecords,
    required List<Map<String, Object?>> steadyRecords,
    required List<String> issues,
  }) {
    if (acceptance == null) return;
    for (final entry in <String, Object>{
      'steady_trials': _expectedSteadyTrials,
      'steady_frames_per_trial': expectedFramesPerTrial,
      'maximum_trial_attempts': _maximumTrialAttempts,
      'invalid_trial_attempts': invalidAttemptRecords.length,
    }.entries) {
      _expectEqual(
        record: acceptance,
        field: entry.key,
        expected: entry.value,
        label: 'Acceptance',
        issues: issues,
      );
    }
    final retriedTrials = <Object?>{
      for (final record in invalidAttemptRecords) record['trial'],
    }.length;
    _expectEqual(
      record: acceptance,
      field: 'retried_trials',
      expected: retriedTrials,
      label: 'Acceptance',
      issues: issues,
    );
    final reportedFailedPaths = acceptance['failed_steady_paths'];
    final expected = failedSteadyPaths;
    var failedPathsAreInvalid = reportedFailedPaths is! List<Object?>;
    if (reportedFailedPaths is List<Object?>) {
      failedPathsAreInvalid = !_sameList(reportedFailedPaths, expected);
    }
    if (failedPathsAreInvalid) {
      issues.add(
        'Acceptance failed_steady_paths must be $failedSteadyPaths; '
        'got $reportedFailedPaths.',
      );
    }
    final allSteadyPresent = steadyRecords.length == _expectedSteadyTrials;
    final expectedPass = allSteadyPresent && failedSteadyPaths.isEmpty;
    if (acceptance['passed'] != expectedPass) {
      issues.add(
        'Acceptance passed is inconsistent with its steady gates.',
      );
    }
    if (acceptance['passed'] != true) {
      issues.add('Application acceptance did not pass.');
    }
    if (acceptance['enforced'] is! bool) {
      issues.add('Acceptance enforced must be a boolean.');
    }
    if (requireEnforcedBudget && acceptance['enforced'] != true) {
      issues.add('Application frame-budget enforcement was not enabled.');
    }
  }

  String _buildSummary({
    required Map<String, Object?>? environment,
    required Map<String, Object?>? acceptance,
    required List<Map<String, Object?>> steadyRecords,
    required List<Map<String, Object?>> invalidAttemptRecords,
    required List<String> issues,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'InteractiveSwipeDismiss benchmark host validation: '
        '${issues.isEmpty ? 'PASS' : 'FAIL'}',
      )
      ..writeln('Run ID: $expectedRunId')
      ..writeln('Renderer: $expectedRenderer')
      ..writeln('Scenario: $_scenario')
      ..writeln('Retained paint required: $requireRetainedPaint')
      ..writeln(
        'Environment: mode=${environment?['mode'] ?? 'missing'}; '
        'refresh_rate_hz=${environment?['refresh_rate_hz'] ?? 'missing'}; '
        'frame_budget_us=${environment?['frame_budget_us'] ?? 'missing'}',
      )
      ..writeln(
        'Trials: expected=$_expectedSteadyTrials; '
        'valid=${steadyRecords.length}; '
        'invalid_attempts=${invalidAttemptRecords.length}',
      );
    for (final record in steadyRecords) {
      final build = record['build'];
      final raster = record['raster'];
      final dispatch = record['dispatch'];
      buffer.writeln(
        '${record['path']}: build_p99_us=${_field(build, 'p99_us')}; '
        'raster_p99_us=${_field(raster, 'p99_us')}; '
        'dispatch_p99_us=${_field(dispatch, 'p99_us')}; '
        'scroll_drift_px=${record['maximum_scroll_drift_px']}; '
        'probes=${record['probe_builds']}/'
        '${record['probe_layouts']}/${record['probe_paints']}; '
        'dismiss_callbacks=${record['dismiss_callbacks']}; '
        'work_pass=${record['work_p99_within_budget']}; '
        'structural_pass=${record['structural_invariants_passed']}',
      );
    }
    buffer
      ..writeln(
        'Acceptance: passed=${acceptance?['passed'] ?? 'missing'}; '
        'enforced=${acceptance?['enforced'] ?? 'missing'}',
      )
      ..writeln('Issues: ${issues.length}');
    for (final issue in issues) {
      buffer.writeln('- $issue');
    }
    return buffer.toString();
  }

  Object _field(Object? value, String field) {
    if (value is Map<String, Object?>) return value[field] ?? 'missing';
    return 'missing';
  }

  Map<String, num> _summarize(List<int> values) {
    final sortedValues = List<int>.of(values, growable: false)..sort();
    final total = sortedValues.fold<int>(0, (sum, value) => sum + value);
    return <String, num>{
      'minimum_us': sortedValues.first,
      'p50_us': _percentile(sortedValues, 0.50),
      'p90_us': _percentile(sortedValues, 0.90),
      'p99_us': _percentile(sortedValues, 0.99),
      'max_us': sortedValues.last,
      'mean_us': total / sortedValues.length,
    };
  }

  int _percentile(List<int> sortedValues, double percentile) {
    final sorted = List<int>.of(sortedValues, growable: false)..sort();
    final index = ((sorted.length * percentile).ceil() - 1).clamp(
      0,
      sorted.length - 1,
    );
    return sorted[index];
  }

  void _expectEqual({
    required Map<String, Object?> record,
    required String field,
    required Object expected,
    required String label,
    required List<String> issues,
  }) {
    final actual = record[field];
    if (!_sameNumber(actual, expected)) {
      issues.add('$label $field must be $expected; got $actual.');
    }
  }

  bool _sameNumber(Object? first, Object? second) {
    if (first is num && second is num) {
      if (!first.isFinite || !second.isFinite) return first == second;
      return (first.toDouble() - second.toDouble()).abs() <= 0.000000001;
    }
    return first == second;
  }

  bool _sameList(List<Object?> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  bool _isPositiveFiniteNumber(Object? value) {
    return value is num && value.isFinite && value > 0;
  }

  void _requireNonPlaceholder(String value, String label) {
    if (value.trim().isEmpty || value.trim().toLowerCase() == 'unspecified') {
      throw ArgumentError.value(value, label, 'must be a non-placeholder');
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

  Map<String, Object?>? _singleRecord(
    List<Map<String, Object?>> records,
  ) {
    return records.length == 1 ? records.single : null;
  }

  String _errorMessage(Map<String, Object?> record) {
    return record['error']?.toString() ?? 'unknown benchmark error';
  }
}
