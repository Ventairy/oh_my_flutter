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
      watch: true,
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
