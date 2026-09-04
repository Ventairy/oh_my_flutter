import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/native_selectable_text/frame_report.dart';

void main() {
  ui.FrameTiming frame({
    required int build,
    required int raster,
    required int total,
    required int vsync,
  }) {
    return ui.FrameTiming(
      vsyncStart: 0,
      buildStart: vsync,
      buildFinish: vsync + build,
      rasterStart: total - raster,
      rasterFinish: total,
      rasterFinishWallTime: total,
    );
  }

  test(
    'when separate frame phases miss a 120 Hz budget, '
    'it should report every count and streak',
    () {
      final report = NativeSelectableTextBenchmarkFrameReport.fromFrames(
        frameBudgetMicros: 8333,
        frames: <ui.FrameTiming>[
          frame(build: 1000, raster: 1000, total: 3000, vsync: 100),
          frame(build: 9000, raster: 1000, total: 12000, vsync: 100),
          frame(build: 1000, raster: 9000, total: 13000, vsync: 100),
          frame(build: 1000, raster: 1000, total: 10000, vsync: 100),
          frame(build: 1000, raster: 1000, total: 11000, vsync: 9000),
          frame(build: 1000, raster: 1000, total: 3000, vsync: 100),
        ],
      );

      expect(
        <String, Object>{
          'build': report.buildOverBudget,
          'raster': report.rasterOverBudget,
          'total': report.totalSpanOverBudget,
          'vsync': report.vsyncOverBudget,
          'work': report.workOverBudget,
          'any': report.anyOverBudget,
          'longest_work': report.longestWorkMissStreak,
          'longest_any': report.longestAnyMissStreak,
          'p99_pass': report.workP99WithinBudget,
        },
        <String, Object>{
          'build': 1,
          'raster': 1,
          'total': 4,
          'vsync': 1,
          'work': 2,
          'any': 4,
          'longest_work': 2,
          'longest_any': 4,
          'p99_pass': false,
        },
      );
    },
  );

  test(
    'when all work fits the refresh budget, it should pass its p99 gate',
    () {
      final report = NativeSelectableTextBenchmarkFrameReport.fromFrames(
        frameBudgetMicros: 16666,
        frames: <ui.FrameTiming>[
          frame(build: 2000, raster: 3000, total: 7000, vsync: 500),
          frame(build: 4000, raster: 5000, total: 11000, vsync: 700),
        ],
      );

      expect(report.workP99WithinBudget, isTrue);
    },
  );

  test(
    'when no frame timings are supplied, it should reject the window',
    () {
      expect(
        () => NativeSelectableTextBenchmarkFrameReport.fromFrames(
          frames: const <ui.FrameTiming>[],
          frameBudgetMicros: 16666,
        ),
        throwsArgumentError,
      );
    },
  );
}
