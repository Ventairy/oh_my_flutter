import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/contour/contour_benchmark_presentation_tracker.dart';

void main() {
  test('when blank frames precede the pair, it should measure them separately from raster latency', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 1000)
      ..observe(
        frameNumber: 1,
        samples: [
          {
            'lastMainCompositionFrameNumber': 1,
            'lastMainCompositionHasContent': false,
            'lastMainCompositionHasContour': false,
          },
        ],
      )
      ..observe(
        frameNumber: 2,
        samples: [
          {
            'lastMainCompositionFrameNumber': 2,
            'lastMainCompositionHasContent': false,
            'lastMainCompositionHasContour': false,
          },
        ],
      )
      ..observe(
        frameNumber: 3,
        samples: [
          {
            'firstPresentationFrameNumber': 3,
            'firstPresentationHasContour': true,
            'lastMainCompositionFrameNumber': 3,
            'lastMainCompositionHasContent': true,
            'lastMainCompositionHasContour': true,
          },
        ],
      )
      ..recordTimings([
        ui.FrameTiming(
          vsyncStart: 1100,
          buildStart: 1200,
          buildFinish: 1300,
          rasterStart: 1400,
          rasterFinish: 1500,
          rasterFinishWallTime: 1500,
          frameNumber: 3,
        ),
      ], receivedTimelineUs: 2000);
    final result = tracker.summarize();
    expect(
      [
        result['blank_compositions_before_pair_total'],
        result['child_only_compositions_before_pair_total'],
        result['all_paired_raster_finish_us'],
      ],
      [2, 0, 500],
    );
  });

  test('when a child appears alone first, it should retain evidence of that failure', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 0)
      ..observe(
        frameNumber: 2,
        samples: [
          {
            'firstPresentationFrameNumber': 2,
            'firstPresentationHasContour': false,
            'lastMainCompositionFrameNumber': 2,
            'lastMainCompositionHasContent': true,
            'lastMainCompositionHasContour': false,
          },
        ],
      )
      ..observe(
        frameNumber: 3,
        samples: [
          {
            'firstPresentationFrameNumber': 2,
            'firstPresentationHasContour': false,
            'lastMainCompositionFrameNumber': 3,
            'lastMainCompositionHasContent': true,
            'lastMainCompositionHasContour': true,
          },
        ],
      );
    final result = tracker.summarize();
    expect(
      [
        result['first_visible_without_contour'],
        result['child_only_compositions_before_pair_total'],
        result['paired_instances'],
      ],
      [1, 1, 1],
    );
  });

  test('when frame timing arrives before its observation, it should still match the frame identity', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 1000)
      ..recordTimings([
        ui.FrameTiming(
          vsyncStart: 1100,
          buildStart: 1200,
          buildFinish: 1300,
          rasterStart: 1400,
          rasterFinish: 1500,
          rasterFinishWallTime: 1500,
          frameNumber: 7,
        ),
      ], receivedTimelineUs: 2000)
      ..observe(
        frameNumber: 7,
        samples: [
          {'firstPresentationFrameNumber': 7, 'firstPresentationHasContour': true},
        ],
      );
    expect(tracker.summarize()['all_paired_raster_finish_us'], 500);
  });

  test('when a frame is observed twice, it should count that composition only once', () {
    final samples = [
      {
        'lastMainCompositionFrameNumber': 1,
        'lastMainCompositionHasContent': false,
        'lastMainCompositionHasContour': false,
      },
    ];
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 0)
      ..observe(frameNumber: 1, samples: samples)
      ..observe(frameNumber: 1, samples: samples);
    expect(tracker.summarize()['blank_compositions_before_pair_total'], 1);
  });

  test('when a retained layer has no new main composition, it should not invent a blank frame', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 0)
      ..observe(
        frameNumber: 2,
        samples: [
          {
            'lastMainCompositionFrameNumber': 1,
            'lastMainCompositionHasContent': false,
            'lastMainCompositionHasContour': false,
          },
        ],
      );
    expect(tracker.summarize()['blank_compositions_before_pair_total'], isNull);
  });

  test('when frame IDs are unsupported, it should report missing latency rather than zero', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 0)
      ..observe(
        frameNumber: -1,
        samples: [
          {'firstPresentationFrameNumber': -1, 'firstPresentationHasContour': true},
        ],
      );
    final result = tracker.summarize();
    expect([result['status'], result['all_paired_raster_finish_us']], ['unsupported_or_not_observed', null]);
  });

  test('when a presented frame has no timing match, it should identify the unmatched measurement', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 0)
      ..observe(
        frameNumber: 4,
        samples: [
          {'firstPresentationFrameNumber': 4, 'firstPresentationHasContour': true},
        ],
      );
    final result = tracker.summarize();
    expect([result['unmatched_paired_instances'], result['all_paired_raster_finish_us']], [1, null]);
  });

  test('when timing retention fills, it should preserve previously matched first appearance', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 0)
      ..observe(
        frameNumber: 1,
        samples: [
          {'firstPresentationFrameNumber': 1, 'firstPresentationHasContour': true},
        ],
      );
    for (var frame = 1; frame <= ContourBenchmarkPresentationTracker.maximumTimingRecords + 1; frame++) {
      tracker.recordTimings([
        ui.FrameTiming(
          vsyncStart: frame,
          buildStart: frame + 1,
          buildFinish: frame + 2,
          rasterStart: frame + 3,
          rasterFinish: frame + 4,
          rasterFinishWallTime: frame + 4,
          frameNumber: frame,
        ),
      ], receivedTimelineUs: frame + 10);
    }
    final result = tracker.summarize();
    expect(
      [result['all_paired_raster_finish_us'], result['retained_timing_records']],
      [5, ContourBenchmarkPresentationTracker.maximumTimingRecords],
    );
  });

  test('when optional renderer diagnostics are absent, it should leave appearance unmeasured', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 0)
      ..observe(frameNumber: 1, samples: [{}]);
    expect(tracker.summarize()['all_first_visible_raster_finish_us'], isNull);
  });

  test('when a timing ends after its receipt clock, it should reject the clock mismatch', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 1000)
      ..observe(
        frameNumber: 1,
        samples: [
          {'firstPresentationFrameNumber': 1, 'firstPresentationHasContour': true},
        ],
      )
      ..recordTimings([
        ui.FrameTiming(
          vsyncStart: 1100,
          buildStart: 1200,
          buildFinish: 1300,
          rasterStart: 1400,
          rasterFinish: 1500,
          rasterFinishWallTime: 1500,
          frameNumber: 1,
        ),
      ], receivedTimelineUs: 1400);
    final result = tracker.summarize();
    expect([result['clock_status'], result['all_paired_raster_finish_us']], ['incompatible_samples', null]);
  });

  test('when one timing batch exceeds retention, it should match referenced frames before eviction', () {
    final tracker = ContourBenchmarkPresentationTracker(instances: 1, startTimelineUs: 0)
      ..observe(
        frameNumber: 1,
        samples: [
          {'firstPresentationFrameNumber': 1, 'firstPresentationHasContour': true},
        ],
      )
      ..recordTimings(
        List.generate(ContourBenchmarkPresentationTracker.maximumTimingRecords + 1, (index) {
          final frame = index + 1;
          return ui.FrameTiming(
            vsyncStart: frame,
            buildStart: frame + 1,
            buildFinish: frame + 2,
            rasterStart: frame + 3,
            rasterFinish: frame + 4,
            rasterFinishWallTime: frame + 4,
            frameNumber: frame,
          );
        }),
        receivedTimelineUs: 10000,
      );
    expect(tracker.summarize()['all_paired_raster_finish_us'], 5);
  });
}
