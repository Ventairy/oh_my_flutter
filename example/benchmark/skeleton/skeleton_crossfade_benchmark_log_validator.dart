import 'dart:convert';

/// Validates complete, labeled logs from the profile-mode crossfade workload.
final class SkeletonCrossfadeBenchmarkLogValidator {
  /// Creates a validator for one fresh process and its expected workload.
  const new({
    required this.runId,
    required this.variant,
    required this.source,
    required this.renderer,
    required this.topology,
    required this.effect,
    required this.cardCount,
    required this.warmupSwitches,
    required this.measuredSwitches,
    this.requireBudgetPass = false,
    this.requireEnforced = false,
  });

  static const String _recordMarker = 'SKELETON_BENCHMARK ';
  static const String _chunkMarker = 'SKELETON_BENCHMARK_CHUNK ';

  /// Run identifier supplied to the application.
  final String runId;

  /// Baseline or candidate source label supplied to the application.
  final String variant;

  /// Human-readable identity of the measured source tree.
  final String source;

  /// Renderer verified from startup or device logs.
  final String renderer;

  /// Single parent or many independent Skeleton instances.
  final String topology;

  /// Static or shimmer skeleton paint.
  final String effect;

  /// Number of cards in the benchmark view.
  final int cardCount;

  /// Number of untimed switches before sampling.
  final int warmupSwitches;

  /// Number of timed switches across both directions.
  final int measuredSwitches;

  /// Whether build and raster p99 must each meet the frame budget.
  final bool requireBudgetPass;

  /// Whether the application was required to enforce the frame budget.
  final bool requireEnforced;

  /// Parses [log] and returns canonical records and validation issues.
  ({List<Map<String, Object?>> records, List<String> issues}) validate(String log) {
    final issues = <String>[];
    final records = _decodeRecords(log, issues);
    final paths = <String, Map<String, Object?>>{};
    for (final record in records) {
      final path = record['path'];
      if (path is! String || path.isEmpty) {
        issues.add('A record has no path.');
        continue;
      }
      if (paths.containsKey(path)) issues.add('Duplicate record path $path.');
      paths[path] = record;
      if (record['run_id'] != runId) issues.add('$path has a different run ID.');
    }

    final expectedPaths = <String>{'environment', 'to_content', 'to_skeleton', 'acceptance'};
    if (paths.keys.toSet().difference(expectedPaths).isNotEmpty) {
      issues.add('Unexpected paths: ${paths.keys.toSet().difference(expectedPaths).join(', ')}.');
    }
    for (final path in expectedPaths) {
      if (!paths.containsKey(path)) issues.add('Missing $path record.');
    }
    final environment = paths['environment'];
    if (environment != null) _validateEnvironment(environment, issues);
    final budget = environment?['frame_budget_us'];
    final content = paths['to_content'];
    final skeleton = paths['to_skeleton'];
    if (content != null) _validateDirection(content, budget, issues);
    if (skeleton != null) _validateDirection(skeleton, budget, issues);
    final acceptance = paths['acceptance'];
    if (acceptance != null) {
      _equal(acceptance, 'variant', variant, issues);
      _equal(acceptance, 'source', source, issues);
      _equal(acceptance, 'measured_switches', measuredSwitches, issues);
      if (acceptance['passed'] != true) issues.add('Application acceptance is not true.');
      if (requireEnforced && acceptance['enforced'] != true) {
        issues.add('Application did not enforce the frame budget.');
      }
    }
    if (records.length != expectedPaths.length) {
      issues.add('Expected exactly ${expectedPaths.length} records; found ${records.length}.');
    }
    return (records: List<Map<String, Object?>>.unmodifiable(records), issues: List<String>.unmodifiable(issues));
  }

  List<Map<String, Object?>> _decodeRecords(String log, List<String> issues) {
    final records = <Map<String, Object?>>[];
    final chunks = <int, List<String?>>{};
    for (final line in const LineSplitter().convert(log)) {
      final recordAt = line.indexOf(_recordMarker);
      if (recordAt >= 0) {
        _decodeRecord(line.substring(recordAt + _recordMarker.length), records, issues);
        continue;
      }
      final chunkAt = line.indexOf(_chunkMarker);
      if (chunkAt < 0) continue;
      try {
        final decoded = jsonDecode(line.substring(chunkAt + _chunkMarker.length));
        if (decoded is! Map<String, dynamic>) throw const FormatException('chunk is not a JSON object');
        final id = decoded['record'];
        final index = decoded['index'];
        final count = decoded['count'];
        final payload = decoded['payload'];
        if (id is! int ||
            index is! int ||
            count is! int ||
            payload is! String ||
            id < 0 ||
            count < 1 ||
            index < 0 ||
            index >= count) {
          throw const FormatException('invalid chunk metadata');
        }
        final parts = chunks.putIfAbsent(id, () => List<String?>.filled(count, null));
        if (parts.length != count || parts[index] != null) {
          throw const FormatException('inconsistent or duplicate chunk');
        }
        parts[index] = payload;
      } on FormatException catch (error) {
        issues.add('Invalid chunk: ${error.message}.');
      }
    }
    for (final entry in chunks.entries) {
      if (entry.value.any((part) => part == null)) {
        issues.add('Chunked record ${entry.key} is incomplete.');
        continue;
      }
      try {
        _decodeRecord(utf8.decode(base64Decode(entry.value.cast<String>().join())), records, issues);
      } on FormatException catch (error) {
        issues.add('Chunked record ${entry.key} is invalid: ${error.message}.');
      }
    }
    return records;
  }

  void _decodeRecord(String payload, List<Map<String, Object?>> records, List<String> issues) {
    try {
      final value = jsonDecode(payload);
      if (value is! Map<String, dynamic>) throw const FormatException('record is not a JSON object');
      records.add(Map<String, Object?>.unmodifiable(value));
    } on FormatException catch (error) {
      issues.add('Invalid record: ${error.message}.');
    }
  }

  void _validateEnvironment(Map<String, Object?> record, List<String> issues) {
    _equal(record, 'variant', variant, issues);
    _equal(record, 'source', source, issues);
    _equal(record, 'renderer', renderer, issues);
    _equal(record, 'topology', topology, issues);
    _equal(record, 'effect', effect, issues);
    _equal(record, 'card_count', cardCount, issues);
    _equal(record, 'warmup_switches', warmupSwitches, issues);
    _equal(record, 'measured_switches', measuredSwitches, issues);
    _equal(record, 'transition_duration_us', 300000, issues);
    _equal(record, 'animations_disabled', false, issues);
    _equal(record, 'mode', 'profile', issues);
    final refreshRate = record['refresh_rate_hz'];
    final budget = record['frame_budget_us'];
    if (refreshRate is! num ||
        !refreshRate.isFinite ||
        refreshRate <= 0 ||
        budget is! int ||
        budget != (1000000 / refreshRate).floor()) {
      issues.add('Environment has invalid refresh rate or frame budget.');
    }
    for (final key in const <String>['logical_size', 'physical_size']) {
      final value = record[key];
      if (value is! Map<String, dynamic> || !_positive(value['width']) || !_positive(value['height'])) {
        issues.add('Environment $key must have positive finite dimensions.');
      }
    }
    if (!_positive(record['device_pixel_ratio'])) {
      issues.add('Environment device_pixel_ratio must be positive and finite.');
    }
  }

  void _validateDirection(Map<String, Object?> record, Object? budget, List<String> issues) {
    final path = record['path'];
    _equal(record, 'variant', variant, issues);
    _equal(record, 'source', source, issues);
    _equal(record, 'switches', measuredSwitches ~/ 2, issues);
    final switches = record['switches'];
    final frames = record['frames'];
    if (switches is! int || frames is! int || frames < switches * 2) {
      issues.add('$path has too few timed frames.');
      return;
    }
    final minFrames = record['min_frames_per_switch'];
    final maxFrames = record['max_frames_per_switch'];
    if (minFrames is! int ||
        maxFrames is! int ||
        minFrames < 2 ||
        maxFrames < minFrames ||
        maxFrames > frames ||
        minFrames * switches > frames ||
        maxFrames * switches < frames) {
      issues.add('$path has invalid per-switch frame counts.');
    }
    final paints = record['probe_paints'];
    if (paints is! int || paints < 0) issues.add('$path has invalid probe_paints.');
    final buildP99 = _validateStatistics(record['build'], '$path build', issues);
    final rasterP99 = _validateStatistics(record['raster'], '$path raster', issues);
    _validateStatistics(record['total_span'], '$path total_span', issues);
    _validateStatistics(record['worst_build_per_switch'], '$path worst_build_per_switch', issues);
    _validateStatistics(record['worst_raster_per_switch'], '$path worst_raster_per_switch', issues);
    _validateStatistics(record['worst_frame_start_gap_per_switch'], '$path worst_frame_start_gap_per_switch', issues);
    if (budget is! int || record['frame_budget_us'] != budget) {
      issues.add('$path has a mismatched frame budget.');
      return;
    }
    final fits = buildP99 != null && rasterP99 != null && buildP99 <= budget && rasterP99 <= budget;
    if (record['work_p99_within_budget'] != fits) issues.add('$path has inconsistent work_p99_within_budget.');
    if (requireBudgetPass && !fits) issues.add('$path missed its build/raster p99 budget.');
    for (final key in const <String>['build_over_budget', 'raster_over_budget', 'total_span_over_budget']) {
      final count = record[key];
      if (count is! int || count < 0 || count > frames) issues.add('$path has invalid $key.');
    }
    final longGapThreshold = record['long_frame_gap_threshold_us'];
    if (longGapThreshold is! int || longGapThreshold != (budget * 1.5).ceil()) {
      issues.add('$path has an invalid long frame gap threshold.');
    }
    final switchesWithLongGap = record['switches_with_long_frame_start_gap'];
    if (switchesWithLongGap is! int || switchesWithLongGap < 0 || switchesWithLongGap > switches) {
      issues.add('$path has an invalid long frame gap count.');
    }
  }

  num? _validateStatistics(Object? value, String label, List<String> issues) {
    if (value is! Map<String, dynamic>) {
      issues.add('$label is missing statistics.');
      return null;
    }
    final entries = <num>[];
    for (final key in const <String>['p50_us', 'p90_us', 'p99_us', 'max_us', 'mean_us']) {
      final item = value[key];
      if (item is! num || !item.isFinite || item < 0) {
        issues.add('$label has invalid $key.');
        return null;
      }
      entries.add(item);
    }
    if (entries[0] > entries[1] || entries[1] > entries[2] || entries[2] > entries[3] || entries[4] > entries[3]) {
      issues.add('$label statistics are inconsistent.');
    }
    return entries[2];
  }

  void _equal(Map<String, Object?> record, String key, Object expected, List<String> issues) {
    if (record[key] != expected) issues.add('${record['path']} $key must be $expected; got ${record[key]}.');
  }

  bool _positive(Object? value) => value is num && value.isFinite && value > 0;
}
