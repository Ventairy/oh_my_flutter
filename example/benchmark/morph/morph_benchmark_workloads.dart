import 'dart:math' as math;

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
    Duration duration = const Duration(milliseconds: 320),
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    const scenario = MorphBenchmarkScenario.descendantSnapshotDense;
    var alignment = const Alignment(-0.18, -0.5);
    var surfaceColor = const Color(0xFFFFF0E6);
    if (expanded) {
      alignment = const Alignment(0.18, 0.18);
      surfaceColor = const Color(0xFFE8F1FF);
    }
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
          width: expanded ? 350 : 286,
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
              (index) => _denseSnapshotDescendant(
                index: index,
                expanded: expanded,
              ),
              growable: false,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _denseSnapshotDescendant({
    required int index,
    required bool expanded,
  }) {
    var color = const Color(0xFFFF4A4B);
    if (index.isEven) color = const Color(0xFF3057D5);
    return MorphDescendant(
      key: ValueKey<int>(index),
      flightBehavior: MorphDescendantFlightBehavior.snapshot,
      child: DecoratedBox(
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
      ),
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
