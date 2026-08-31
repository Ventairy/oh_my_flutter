import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Counts paints performed while Morph captures a watched snapshot.
final class MorphBenchmarkSnapshotPaintProbe extends CustomPainter {
  /// Creates a probe with generation zero and no recorded paints.
  factory MorphBenchmarkSnapshotPaintProbe() {
    final generation = ValueNotifier<int>(0);
    return MorphBenchmarkSnapshotPaintProbe._(generation);
  }

  MorphBenchmarkSnapshotPaintProbe._(ValueNotifier<int> generation)
    : _generation = generation,
      super(repaint: generation);

  final ValueNotifier<int> _generation;
  final List<(int, int)> _paintEvents = <(int, int)>[];

  /// Latest content generation requested by the benchmark workload.
  int get requestedGeneration => _generation.value;

  /// Notifications and values used to rebuild the changing destination.
  ValueListenable<int> get changes => _generation;

  /// Number of paints recorded since this probe was created.
  int get paintEventCount => _paintEvents.length;

  /// Content generation observed by the latest paint, if any.
  int? get lastPaintedGeneration {
    if (_paintEvents.isEmpty) return null;
    return _paintEvents.last.$2;
  }

  /// Requests one or more synchronous pixel changes for one benchmark frame.
  void requestMutationBatch({int mutations = 3}) {
    assert(mutations > 0, 'A mutation batch must contain at least one change.');
    for (var mutation = 0; mutation < mutations; mutation += 1) {
      _generation.value += 1;
    }
  }

  /// Summarizes paints from [firstEvent] until [lastEvent] or the latest paint.
  ({
    List<int> capturedGenerations,
    int capturePaints,
    int finalCapturedGeneration,
    int maxCapturePaintsPerFrame,
  })
  measureSince(int firstEvent, {int? lastEvent}) {
    final end = lastEvent ?? _paintEvents.length;
    assert(
      firstEvent >= 0 && firstEvent <= end && end <= _paintEvents.length,
      'The paint event range must belong to this probe.',
    );
    final events = _paintEvents.sublist(firstEvent, end);
    final paintsPerFrame = <int, int>{};
    for (final event in events) {
      paintsPerFrame.update(
        event.$1,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    var maxPaintsPerFrame = 0;
    for (final paints in paintsPerFrame.values) {
      maxPaintsPerFrame = math.max(maxPaintsPerFrame, paints);
    }
    final capturedGenerations = <int>[
      for (final event in events) event.$2,
    ];
    return (
      capturedGenerations: capturedGenerations,
      capturePaints: events.length,
      finalCapturedGeneration: events.isEmpty ? -1 : events.last.$2,
      maxCapturePaintsPerFrame: maxPaintsPerFrame,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scheduler = SchedulerBinding.instance;
    final frameMicros = scheduler.currentSystemFrameTimeStamp.inMicroseconds;
    _paintEvents.add((frameMicros, requestedGeneration));
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        math.min(size.width, 4),
        math.min(size.height, 4),
      ),
      Paint()..color = Color(0xFF000000 | requestedGeneration),
    );
  }

  @override
  bool shouldRepaint(MorphBenchmarkSnapshotPaintProbe oldDelegate) {
    return !identical(this, oldDelegate);
  }

  /// Releases the notifier used to drive paint-only pixel mutations.
  void dispose() {
    _generation.dispose();
  }
}
