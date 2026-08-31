import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_snapshot_paint_probe.dart';

void main() {
  testWidgets(
    'when one snapshot change occurs in a frame, '
    'it should record that generation once',
    (tester) async {
      final probe = MorphBenchmarkSnapshotPaintProbe();
      addTearDown(probe.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            painter: probe,
            size: const Size(40, 30),
          ),
        ),
      );
      await tester.pump();
      final firstEvent = probe.paintEventCount;

      probe.requestMutationBatch(mutations: 1);
      await tester.pump();
      final measurement = probe.measureSince(firstEvent);

      expect(
        (
          measurement.capturePaints,
          measurement.capturedGenerations.single,
          probe.requestedGeneration,
        ),
        (1, 1, 1),
      );
    },
  );

  testWidgets(
    'when three snapshot changes occur in one frame, '
    'it should record one paint of the latest generation',
    (tester) async {
      final probe = MorphBenchmarkSnapshotPaintProbe();
      addTearDown(probe.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            painter: probe,
            size: const Size(40, 30),
          ),
        ),
      );
      await tester.pump();
      final firstEvent = probe.paintEventCount;

      probe.requestMutationBatch();
      await tester.pump();
      final measurement = probe.measureSince(firstEvent);

      expect(
        (
          measurement.capturePaints,
          measurement.finalCapturedGeneration,
          measurement.maxCapturePaintsPerFrame,
          measurement.capturedGenerations.single,
          probe.lastPaintedGeneration,
          probe.requestedGeneration,
        ),
        (1, 3, 1, 3, 3, 3),
      );
    },
  );
}
