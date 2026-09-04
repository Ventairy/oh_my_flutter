import 'dart:math' as math;
import 'dart:ui' as ui;

/// Summarizes one attributed NativeSelectableText benchmark frame window.
final class NativeSelectableTextBenchmarkFrameReport {
  /// Measures [frames] against the refresh-derived [frameBudgetMicros].
  factory NativeSelectableTextBenchmarkFrameReport.fromFrames({
    required List<ui.FrameTiming> frames,
    required int frameBudgetMicros,
  }) {
    if (frames.isEmpty) {
      throw ArgumentError.value(frames, 'frames', 'must not be empty');
    }
    if (frameBudgetMicros < 1) {
      throw ArgumentError.value(
        frameBudgetMicros,
        'frameBudgetMicros',
        'must be positive',
      );
    }

    final buildMicros = <int>[];
    final rasterMicros = <int>[];
    final totalSpanMicros = <int>[];
    final vsyncOverheadMicros = <int>[];
    var buildOverBudget = 0;
    var rasterOverBudget = 0;
    var totalSpanOverBudget = 0;
    var vsyncOverBudget = 0;
    var workOverBudget = 0;
    var anyOverBudget = 0;
    var currentWorkMissStreak = 0;
    var longestWorkMissStreak = 0;
    var currentAnyMissStreak = 0;
    var longestAnyMissStreak = 0;

    for (final frame in frames) {
      final build = frame.buildDuration.inMicroseconds;
      final raster = frame.rasterDuration.inMicroseconds;
      final totalSpan = frame.totalSpan.inMicroseconds;
      final vsyncOverhead = frame.vsyncOverhead.inMicroseconds;
      buildMicros.add(build);
      rasterMicros.add(raster);
      totalSpanMicros.add(totalSpan);
      vsyncOverheadMicros.add(vsyncOverhead);

      final buildMissed = build > frameBudgetMicros;
      final rasterMissed = raster > frameBudgetMicros;
      final totalSpanMissed = totalSpan > frameBudgetMicros;
      final vsyncMissed = vsyncOverhead > frameBudgetMicros;
      if (buildMissed) buildOverBudget += 1;
      if (rasterMissed) rasterOverBudget += 1;
      if (totalSpanMissed) totalSpanOverBudget += 1;
      if (vsyncMissed) vsyncOverBudget += 1;

      final workMissed = buildMissed || rasterMissed;
      if (workMissed) {
        workOverBudget += 1;
        currentWorkMissStreak += 1;
        longestWorkMissStreak = math.max(
          longestWorkMissStreak,
          currentWorkMissStreak,
        );
      } else {
        currentWorkMissStreak = 0;
      }

      final anyMissed = workMissed || totalSpanMissed || vsyncMissed;
      if (anyMissed) {
        anyOverBudget += 1;
        currentAnyMissStreak += 1;
        longestAnyMissStreak = math.max(
          longestAnyMissStreak,
          currentAnyMissStreak,
        );
      } else {
        currentAnyMissStreak = 0;
      }
    }

    final build = _summarize(buildMicros);
    final raster = _summarize(rasterMicros);
    final buildP99 = build['p99_us']!;
    final rasterP99 = raster['p99_us']!;
    final buildFitsBudget = buildP99 <= frameBudgetMicros;
    final rasterFitsBudget = rasterP99 <= frameBudgetMicros;
    return NativeSelectableTextBenchmarkFrameReport._(
      frames: frames.length,
      build: build,
      raster: raster,
      totalSpan: _summarize(totalSpanMicros),
      vsyncOverhead: _summarize(vsyncOverheadMicros),
      buildOverBudget: buildOverBudget,
      rasterOverBudget: rasterOverBudget,
      totalSpanOverBudget: totalSpanOverBudget,
      vsyncOverBudget: vsyncOverBudget,
      workOverBudget: workOverBudget,
      anyOverBudget: anyOverBudget,
      longestWorkMissStreak: longestWorkMissStreak,
      longestAnyMissStreak: longestAnyMissStreak,
      workP99WithinBudget: buildFitsBudget && rasterFitsBudget,
    );
  }

  const NativeSelectableTextBenchmarkFrameReport._({
    required this.frames,
    required this.build,
    required this.raster,
    required this.totalSpan,
    required this.vsyncOverhead,
    required this.buildOverBudget,
    required this.rasterOverBudget,
    required this.totalSpanOverBudget,
    required this.vsyncOverBudget,
    required this.workOverBudget,
    required this.anyOverBudget,
    required this.longestWorkMissStreak,
    required this.longestAnyMissStreak,
    required this.workP99WithinBudget,
  });

  /// Number of attributed frames in this report.
  final int frames;

  /// Build-duration distribution in microseconds.
  final Map<String, num> build;

  /// Raster-duration distribution in microseconds.
  final Map<String, num> raster;

  /// End-to-end frame-span distribution in microseconds.
  final Map<String, num> totalSpan;

  /// Delay from vsync to UI-thread build start in microseconds.
  final Map<String, num> vsyncOverhead;

  /// Frames whose build duration exceeded the display budget.
  final int buildOverBudget;

  /// Frames whose raster duration exceeded the display budget.
  final int rasterOverBudget;

  /// Frames whose total span exceeded the display budget.
  final int totalSpanOverBudget;

  /// Frames whose delay after vsync exceeded the display budget.
  final int vsyncOverBudget;

  /// Frames whose build or raster work exceeded the display budget.
  final int workOverBudget;

  /// Frames for which any measured latency exceeded the display budget.
  final int anyOverBudget;

  /// Longest adjacent run of build-or-raster misses.
  final int longestWorkMissStreak;

  /// Longest adjacent run in which any measured latency missed its budget.
  final int longestAnyMissStreak;

  /// Whether build and raster p99 both fit the display budget.
  final bool workP99WithinBudget;

  /// Converts the report to its machine-readable benchmark schema.
  Map<String, Object> toJson() {
    return <String, Object>{
      'frames': frames,
      'build': build,
      'raster': raster,
      'total_span': totalSpan,
      'vsync_overhead': vsyncOverhead,
      'build_over_budget': buildOverBudget,
      'raster_over_budget': rasterOverBudget,
      'total_span_over_budget': totalSpanOverBudget,
      'vsync_over_budget': vsyncOverBudget,
      'work_over_budget': workOverBudget,
      'any_over_budget': anyOverBudget,
      'longest_work_miss_streak': longestWorkMissStreak,
      'longest_any_miss_streak': longestAnyMissStreak,
      'work_p99_within_budget': workP99WithinBudget,
    };
  }

  static Map<String, num> _summarize(List<int> values) {
    values.sort();
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return <String, num>{
      'mean_us': total / values.length,
      'p50_us': _percentile(values, 0.50),
      'p90_us': _percentile(values, 0.90),
      'p99_us': _percentile(values, 0.99),
      'max_us': values.last,
    };
  }

  static int _percentile(List<int> sortedValues, double percentile) {
    final unboundedIndex = (sortedValues.length * percentile).ceil() - 1;
    final index = unboundedIndex.clamp(0, sortedValues.length - 1);
    return sortedValues[index];
  }
}
