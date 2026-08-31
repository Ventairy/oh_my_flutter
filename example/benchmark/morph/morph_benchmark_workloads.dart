import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'morph_benchmark_scenario.dart';

/// Builds the benchmark stages that exercise specialized Morph workloads.
abstract final class MorphBenchmarkWorkloads {
  /// Duration of the outer flight in the nested watch-and-hold workload.
  static const nestedWatchParentDuration = Duration(milliseconds: 640);

  /// Duration of the watched inner flight in the nested watch-and-hold
  /// workload.
  static const nestedWatchChildDuration = Duration(milliseconds: 160);

  /// Builds one configured descendant inside a resizing surface.
  static Widget descendant({
    required bool expanded,
    required MorphDescendantFlightBehavior behavior,
    Duration duration = const Duration(milliseconds: 320),
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    const liveScenario = MorphBenchmarkScenario.descendantLive;
    const snapshotScenario = MorphBenchmarkScenario.descendantSnapshot;
    const hideScenario = MorphBenchmarkScenario.descendantHide;
    final scenario = switch (behavior) {
      MorphDescendantFlightBehavior.live => liveScenario,
      MorphDescendantFlightBehavior.snapshot => snapshotScenario,
      MorphDescendantFlightBehavior.hide => hideScenario,
    };
    var alignment = const Alignment(-0.24, -0.62);
    var surfaceColor = const Color(0xFFFFF0E6);
    if (expanded) {
      alignment = const Alignment(0.24, 0.24);
      surfaceColor = const Color(0xFFE8F1FF);
    }
    const destinationText =
        'Captured destination content remains visually fixed while '
        'the surrounding surface changes its size and position.\n\n'
        'The repeated paragraph makes both layout and painting '
        'representative of an editor or scrolling description.';
    const sourceText =
        'Compact source content.\n\n'
        'The descendant occupies a smaller endpoint.';
    return Align(
      alignment: alignment,
      child: Morph(
        tag: 'benchmark-${scenario.id}',
        duration: duration,
        onStart: onStart,
        onEnd: onEnd,
        child: Container(
          key: _endpointKey(
            scenario: scenario,
            child: 'surface',
            expanded: expanded,
          ),
          width: expanded ? 342 : 236,
          height: expanded ? 286 : 164,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(expanded ? 34 : 18),
          ),
          child: MorphDescendant(
            key: const ValueKey<String>('benchmark-descendant'),
            flightBehavior: behavior,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Text(
                expanded ? destinationText : sourceText,
                style: TextStyle(
                  color: const Color(0xFF182033),
                  fontSize: expanded ? 18 : 15,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds twenty-four sibling snapshot descendants in one surface.
  static Widget descendantSnapshotDense({
    required bool expanded,
    bool watchDestination = false,
    bool dynamicWatchedSnapshot = false,
    bool geometryOnlyWatchedSnapshot = false,
    bool nestedSnapshotFallback = false,
    ValueListenable<int>? surfaceChanges,
    CustomPainter? dirtySnapshotPainter,
    CustomPainter? unchangedSnapshotPainter,
    Duration duration = const Duration(milliseconds: 320),
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    assert(
      !dynamicWatchedSnapshot || watchDestination,
      'A dynamic watched snapshot must watch its destination.',
    );
    assert(
      !dynamicWatchedSnapshot || surfaceChanges != null,
      'A dynamic watched snapshot must declare geometry and pixel changes.',
    );
    assert(
      !geometryOnlyWatchedSnapshot || watchDestination,
      'A geometry-only watched snapshot must watch its destination.',
    );
    assert(
      !geometryOnlyWatchedSnapshot || surfaceChanges != null,
      'A geometry-only watched snapshot must declare geometry changes.',
    );
    assert(
      !nestedSnapshotFallback || watchDestination,
      'A nested snapshot fallback must watch its destination.',
    );
    assert(
      <bool>[
            dynamicWatchedSnapshot,
            geometryOnlyWatchedSnapshot,
            nestedSnapshotFallback,
          ].where((enabled) => enabled).length <=
          1,
      'A watched snapshot workload must select only one mutation mode.',
    );
    var scenario = MorphBenchmarkScenario.descendantSnapshotDense;
    if (watchDestination) {
      scenario = MorphBenchmarkScenario.watchSnapshotDense;
    }
    if (dynamicWatchedSnapshot) {
      scenario = MorphBenchmarkScenario.watchSnapshotDynamic;
    }
    if (geometryOnlyWatchedSnapshot) {
      scenario = MorphBenchmarkScenario.watchSnapshotGeometryOnly;
    }
    if (nestedSnapshotFallback) {
      scenario = MorphBenchmarkScenario.watchSnapshotNestedFallback;
    }
    var alignment = const Alignment(-0.18, -0.5);
    var surfaceColor = const Color(0xFFFFF0E6);
    if (expanded) {
      alignment = const Alignment(0.18, 0.18);
      surfaceColor = const Color(0xFFE8F1FF);
    }
    Alignment alignmentForGeneration(int generation) {
      var currentAlignment = alignment;
      if (dynamicWatchedSnapshot || geometryOnlyWatchedSnapshot) {
        final batch = generation ~/ scenario.snapshotMutationsPerBatch;
        final horizontalOffset = batch.isEven ? -0.035 : 0.035;
        currentAlignment = Alignment(
          alignment.x + horizontalOffset,
          alignment.y + ((batch % 3) - 1) * 0.02,
        );
      }
      return currentAlignment;
    }

    Widget buildEndpoint(int generation) {
      var width = expanded ? 350.0 : 286.0;
      if (dynamicWatchedSnapshot) {
        final batch = generation ~/ scenario.snapshotMutationsPerBatch;
        width += (batch % 5) * 2;
      }
      return Morph(
        tag: 'benchmark-${scenario.id}',
        duration: duration,
        watchDestination: watchDestination,
        onStart: onStart,
        onEnd: onEnd,
        child: Container(
          key: _endpointKey(
            scenario: scenario,
            child: 'surface',
            expanded: expanded,
          ),
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(expanded ? 32 : 18),
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List<Widget>.generate(
              24,
              (index) {
                final isFirst = index == 0;
                final isSecond = index == 1;
                CustomPainter? painter;
                if (isFirst) painter = dirtySnapshotPainter;
                if (isSecond) painter = unchangedSnapshotPainter;
                return _denseSnapshotDescendant(
                  index: index,
                  expanded: expanded,
                  snapshotPainter: painter,
                  nestedRepaintBoundary: nestedSnapshotFallback,
                );
              },
              growable: false,
            ),
          ),
        ),
      );
    }

    Widget buildSurface(int generation) {
      return Align(
        alignment: alignmentForGeneration(generation),
        child: buildEndpoint(generation),
      );
    }

    if (surfaceChanges == null) return buildSurface(0);
    if (geometryOnlyWatchedSnapshot) {
      return ValueListenableBuilder<int>(
        valueListenable: surfaceChanges,
        builder: (context, generation, child) {
          return Align(
            alignment: alignmentForGeneration(generation),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: buildEndpoint(0),
        ),
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: surfaceChanges,
      builder: (context, generation, child) => buildSurface(generation),
    );
  }

  /// Builds a near-full-surface watched snapshot that changes on consecutive
  /// benchmark frames while one sibling snapshot remains unchanged.
  static Widget watchedSnapshotFullSurface({
    required bool expanded,
    required ValueListenable<int> surfaceChanges,
    required CustomPainter dirtySnapshotPainter,
    required CustomPainter unchangedSnapshotPainter,
    Duration duration = const Duration(milliseconds: 640),
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    const scenario = MorphBenchmarkScenario.watchSnapshotFullSurface;
    const snapshotBehavior = MorphDescendantFlightBehavior.snapshot;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maximumSize = constraints.biggest;
        var availableWidth = maximumSize.width;
        if (!availableWidth.isFinite) availableWidth = 400.0;
        var availableHeight = maximumSize.height;
        if (!availableHeight.isFinite) availableHeight = 800.0;
        return ValueListenableBuilder<int>(
          valueListenable: surfaceChanges,
          builder: (context, generation, child) {
            final batch = generation ~/ scenario.snapshotMutationsPerBatch;
            final maximumWidth = math.max(1, availableWidth - 24);
            final maximumHeight = math.max(1, availableHeight - 24);
            final baseWidth = math.min(maximumWidth, 356);
            final baseHeight = math.min(
              maximumHeight,
              availableHeight * (expanded ? 0.82 : 0.68),
            );
            final width = math.max(1, baseWidth - (batch % 3) * 2).toDouble();
            final height = math
                .min(
                  maximumHeight,
                  math.max(1, baseHeight + (batch % 5) * 3),
                )
                .toDouble();
            final alignment = Alignment(
              (batch.isEven ? -0.035 : 0.035) + (expanded ? 0.08 : -0.08),
              ((batch % 3) - 1) * 0.025,
            );
            var panelColor = const Color(0xFFE8F1FF);
            if (!batch.isEven) panelColor = const Color(0xFFFFF0E6);
            return Align(
              alignment: alignment,
              child: Morph(
                tag: 'benchmark-${scenario.id}',
                duration: duration,
                watchDestination: true,
                onStart: onStart,
                onEnd: onEnd,
                child: Container(
                  key: _endpointKey(
                    scenario: scenario,
                    child: 'surface',
                    expanded: expanded,
                  ),
                  width: width,
                  height: height,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF182033),
                    borderRadius: BorderRadius.circular(expanded ? 32 : 20),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: MorphDescendant(
                          key: const ValueKey<String>('full-surface-dirty'),
                          flightBehavior: snapshotBehavior,
                          child: CustomPaint(
                            foregroundPainter: dirtySnapshotPainter,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: panelColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'A near-full destination surface changes '
                                    'height and pixels while a watched Morph '
                                    'flight remains active.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF182033),
                                      fontSize: 20,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: MorphDescendant(
                          key: const ValueKey<String>(
                            'full-surface-unchanged',
                          ),
                          flightBehavior: snapshotBehavior,
                          child: CustomPaint(
                            foregroundPainter: unchangedSnapshotPainter,
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: ColoredBox(color: Color(0xFFFF4A4B)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _denseSnapshotDescendant({
    required int index,
    required bool expanded,
    required CustomPainter? snapshotPainter,
    required bool nestedRepaintBoundary,
  }) {
    var color = const Color(0xFFFF4A4B);
    if (index.isEven) color = const Color(0xFF3057D5);
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        width: expanded ? 48 : 38,
        height: expanded ? 36 : 30,
        child: Center(
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    Widget child = tile;
    if (snapshotPainter != null) {
      child = CustomPaint(foregroundPainter: snapshotPainter, child: tile);
    }
    if (nestedRepaintBoundary) {
      child = RepaintBoundary(child: child);
    }
    return MorphDescendant(
      key: ValueKey<int>(index),
      flightBehavior: MorphDescendantFlightBehavior.snapshot,
      child: child,
    );
  }

  /// Builds a Column whose matched ordinary child changes size in flight.
  static Widget columnMatchedRawResize({
    required bool expanded,
    required Duration duration,
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    const scenario = MorphBenchmarkScenario.columnMatchedRawResize;
    final rawChild = DecoratedBox(
      key: const ValueKey<String>('matched-resizing-raw-child'),
      decoration: BoxDecoration(
        color: expanded ? const Color(0xFFDFF7EC) : const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(expanded ? 22 : 12),
      ),
      child: SizedBox(
        width: expanded ? 278 : 166,
        height: expanded ? 126 : 62,
        child: Center(
          child: Text(
            expanded ? 'Ilha comum redimensionada' : 'Ilha comum',
            style: TextStyle(
              fontSize: expanded ? 19 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    final endpoint = Morph(
      tag: 'benchmark-column-matched-raw-resize',
      duration: duration,
      onStart: onStart,
      onEnd: onEnd,
      child: Column(
        key: _endpointKey(
          scenario: scenario,
          child: 'column-matched-raw-resize',
          expanded: expanded,
        ),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            expanded ? 'Coluna híbrida ampliada' : 'Coluna híbrida',
            key: const ValueKey<String>('matched-resize-title'),
            style: TextStyle(
              fontSize: expanded ? 28 : 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          rawChild,
        ],
      ),
    );
    var endpointAlignment = const Alignment(-0.22, -0.62);
    if (expanded) endpointAlignment = const Alignment(0.22, 0.2);
    return Align(
      alignment: endpointAlignment,
      child: endpoint,
    );
  }

  /// Builds a short watched child inside a longer, moving parent flight.
  static Widget nestedWatchHold({
    required bool expanded,
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    const scenario = MorphBenchmarkScenario.nestedWatchHold;
    final nestedEndpoint = Morph(
      tag: 'benchmark-nested-watched-text',
      duration: nestedWatchChildDuration,
      watchDestination: true,
      child: Text(
        key: _endpointKey(
          scenario: scenario,
          child: 'nested-watched-text',
          expanded: expanded,
        ),
        expanded ? 'Destino observado em espera' : 'Origem observada',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: expanded ? 24 : 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      key: const ValueKey<String>('nested-watch-motion'),
      duration: nestedWatchParentDuration,
      tween: Tween<double>(end: expanded ? 1 : 0),
      child: nestedEndpoint,
      builder: (context, progress, child) {
        var surfaceColor = const Color(0xFFF8F9FF);
        var endpointAlignment = const Alignment(-0.18, -0.55);
        if (expanded) {
          surfaceColor = const Color(0xFFEEF2FF);
          endpointAlignment = const Alignment(0.15, 0.15);
        }
        final alignment = Alignment.lerp(
          const Alignment(-0.7, -0.65),
          const Alignment(0.55, 0.55),
          progress,
        )!;
        final pulse = math.sin(math.pi * progress);
        final movingDestination = Align(
          alignment: Alignment(
            alignment.x + pulse * 0.12,
            alignment.y - pulse * 0.08,
          ),
          child: SizedBox(
            key: const ValueKey<String>('nested-watch-target-geometry'),
            width: 190 + progress * 90 + pulse * 28,
            height: 58 + progress * 42 + pulse * 18,
            child: child,
          ),
        );
        final endpoint = Morph(
          tag: 'benchmark-nested-watch-parent',
          duration: nestedWatchParentDuration,
          onStart: onStart,
          onEnd: onEnd,
          child: Container(
            key: _endpointKey(
              scenario: scenario,
              child: 'nested-watch-parent',
              expanded: expanded,
            ),
            width: expanded ? 350 : 300,
            height: expanded ? 420 : 300,
            padding: EdgeInsets.all(expanded ? 28 : 18),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(expanded ? 36 : 22),
            ),
            child: movingDestination,
          ),
        );
        return Align(
          alignment: endpointAlignment,
          child: endpoint,
        );
      },
    );
  }

  static Key _endpointKey({
    required MorphBenchmarkScenario scenario,
    required String child,
    required bool expanded,
  }) {
    return ValueKey<String>(
      scenario.endpointIdentity(child: child, destination: expanded),
    );
  }
}
