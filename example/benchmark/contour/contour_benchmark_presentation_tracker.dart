import 'dart:ui' as ui;

/// Matches observed main compositions to bounded raster timing records.
class ContourBenchmarkPresentationTracker {
  /// Starts a measurement in the engine timeline clock's microseconds.
  new({required int instances, required this.startTimelineUs})
    : _firstVisible = List.filled(instances, null),
      _firstHasContour = List.filled(instances, null),
      _firstPair = List.filled(instances, null),
      _lastObserved = List.filled(instances, null),
      _blank = List.filled(instances, 0),
      _childOnly = List.filled(instances, 0),
      _observations = List.filled(instances, 0),
      _visibleRasterUs = List.filled(instances, null),
      _pairedRasterUs = List.filled(instances, null);

  /// Bounds memory even when a presentation never becomes observable.
  static const maximumTimingRecords = 2048;

  /// Engine timeline timestamp when this measurement's content was requested.
  final int startTimelineUs;
  final List<int?> _firstVisible;
  final List<bool?> _firstHasContour;
  final List<int?> _firstPair;
  final List<int?> _lastObserved;
  final List<int> _blank;
  final List<int> _childOnly;
  final List<int> _observations;
  final List<int?> _visibleRasterUs;
  final List<int?> _pairedRasterUs;
  final Map<int, int> _rasterFinishes = {};
  int _unsupportedFrameObservations = 0;
  int _timingsBeforeStart = 0;
  int _timingsAfterReceipt = 0;
  int _timingEvictions = 0;

  /// Whether every owner has been observed with child and contour together.
  bool get allPaired => _firstPair.every((frame) => frame != null);

  /// Reads only compositions explicitly attributed to this main-scene frame.
  void observe({required int frameNumber, required List<Map<String, Object?>> samples}) {
    assert(samples.length == _firstVisible.length, 'Every contour needs one diagnostic sample.');
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final first = sample['firstPresentationFrameNumber'];
      final firstHasContour = sample['firstPresentationHasContour'];
      if (_firstVisible[index] == null && first is int && first >= 0 && firstHasContour is bool) {
        _firstVisible[index] = first;
        _firstHasContour[index] = firstHasContour;
        if (firstHasContour) _firstPair[index] = first;
      }
      final composed = sample['lastMainCompositionFrameNumber'];
      final hasContent = sample['lastMainCompositionHasContent'];
      final hasContour = sample['lastMainCompositionHasContour'];
      if (frameNumber < 0 || composed is! int || composed < 0) {
        _unsupportedFrameObservations++;
        continue;
      }
      if (composed != frameNumber || _lastObserved[index] == composed || hasContent is! bool || hasContour is! bool) {
        continue;
      }
      _lastObserved[index] = composed;
      _observations[index]++;
      if (_firstPair[index] != null && composed >= _firstPair[index]!) continue;
      if (!hasContent) {
        _blank[index]++;
      } else if (!hasContour) {
        _childOnly[index]++;
      } else {
        _firstPair[index] = composed;
      }
    }
    _matchTimings();
  }

  /// Accepts timing batches before or after the corresponding observation.
  void recordTimings(List<ui.FrameTiming> timings, {required int receivedTimelineUs}) {
    for (final timing in timings) {
      if (timing.frameNumber < 0) continue;
      final finish = timing.timestampInMicroseconds(ui.FramePhase.rasterFinish);
      if (finish > receivedTimelineUs) {
        _timingsAfterReceipt++;
        continue;
      }
      final elapsed = finish - startTimelineUs;
      if (elapsed < 0) {
        _timingsBeforeStart++;
        continue;
      }
      _rasterFinishes[timing.frameNumber] = elapsed;
      if (_rasterFinishes.length > maximumTimingRecords) {
        _matchTimings();
        _rasterFinishes.remove(_rasterFinishes.keys.first);
        _timingEvictions++;
      }
    }
    _matchTimings();
  }

  void _matchTimings() {
    for (var index = 0; index < _firstVisible.length; index++) {
      _visibleRasterUs[index] ??= _rasterFinishes[_firstVisible[index]];
      _pairedRasterUs[index] ??= _rasterFinishes[_firstPair[index]];
    }
  }

  /// Returns compact observed counts; absent evidence never becomes zero latency.
  Map<String, Object?> summarize() {
    final visible = _visibleRasterUs.whereType<int>().toList();
    final paired = _pairedRasterUs.whereType<int>().toList();
    final observed = _observations.where((count) => count > 0).length;
    final firstVisibleCount = _firstVisible.whereType<int>().length;
    final pairedCount = _firstPair.whereType<int>().length;
    return {
      'definition': 'main_composition_matched_raster_finish',
      'hardware_presentation_measured': false,
      'instances': _firstVisible.length,
      'observed_instances': observed,
      'first_visible_instances': firstVisibleCount,
      'first_visible_frame_numbers': _firstVisible,
      'first_visible_has_contour': _firstHasContour,
      'first_paired_frame_numbers': _firstPair,
      'first_visible_raster_finish_us': _visibleRasterUs,
      'paired_raster_finish_us': _pairedRasterUs,
      'blank_compositions_before_pair': [
        for (var index = 0; index < _blank.length; index++)
          if (_observations[index] == 0) null else _blank[index],
      ],
      'child_only_compositions_before_pair': [
        for (var index = 0; index < _childOnly.length; index++)
          if (_observations[index] == 0) null else _childOnly[index],
      ],
      'child_only_observed': _firstHasContour.contains(false) || _childOnly.any((count) => count > 0)
          ? true
          : firstVisibleCount == _firstVisible.length
          ? false
          : null,
      'first_visible_with_contour': _firstHasContour.where((value) => value == true).length,
      'first_visible_without_contour': _firstHasContour.where((value) => value == false).length,
      'paired_instances': pairedCount,
      'first_visible_matched_timings': visible.length,
      'paired_matched_timings': paired.length,
      'unmatched_first_visible_instances': firstVisibleCount - visible.length,
      'unmatched_paired_instances': pairedCount - paired.length,
      'status': paired.length == _firstPair.length
          ? 'complete'
          : observed == 0 && firstVisibleCount == 0
          ? 'unsupported_or_not_observed'
          : 'incomplete_or_unmatched',
      'first_visible_raster_finish_p50_us': _percentile(visible, .5),
      'first_visible_raster_finish_p99_us': _percentile(visible, .99),
      'all_first_visible_raster_finish_us': visible.length == _firstVisible.length ? _percentile(visible, 1) : null,
      'paired_raster_finish_p50_us': _percentile(paired, .5),
      'paired_raster_finish_p99_us': _percentile(paired, .99),
      'all_paired_raster_finish_us': paired.length == _firstPair.length ? _percentile(paired, 1) : null,
      'blank_compositions_before_pair_total': observed == 0 ? null : _blank.fold<int>(0, (sum, count) => sum + count),
      'blank_compositions_before_pair_max': observed == 0 ? null : _blank.reduce((a, b) => a > b ? a : b),
      'child_only_compositions_before_pair_total': observed == 0
          ? null
          : _childOnly.fold<int>(0, (sum, count) => sum + count),
      'child_only_compositions_before_pair_max': observed == 0 ? null : _childOnly.reduce((a, b) => a > b ? a : b),
      'composition_observations': _observations.fold<int>(0, (sum, count) => sum + count),
      'unsupported_frame_observations': _unsupportedFrameObservations,
      'timings_before_measurement_start': _timingsBeforeStart,
      'timings_after_receipt_clock_mismatches': _timingsAfterReceipt,
      'timing_retention_evictions': _timingEvictions,
      'clock_status': _timingsAfterReceipt > 0
          ? 'incompatible_samples'
          : paired.isNotEmpty || visible.isNotEmpty
          ? 'matched_monotonic_samples'
          : 'unverified',
      'retained_timing_records': _rasterFinishes.length,
      'maximum_timing_records': maximumTimingRecords,
    };
  }

  int? _percentile(List<int> values, double fraction) {
    if (values.isEmpty) return null;
    values.sort();
    return values[(values.length * fraction).ceil() - 1];
  }
}
