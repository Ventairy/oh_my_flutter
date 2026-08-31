/// Scenario exercised by the Morph profile benchmark.
enum MorphBenchmarkScenario {
  /// Retained standalone Text flight.
  text('text'),

  /// Retained four-Text Column flight.
  column('column'),

  /// Retained decorated Container flight.
  surface('surface'),

  /// Static foreground control painted above a moving surface flight.
  foregroundStatic('foreground_static'),

  /// Continuously repainting foreground control above a moving surface flight.
  foregroundLive('foreground_live'),

  /// Multiple static foreground controls above a moving surface flight.
  foregroundMultiStatic('foreground_multi_static'),

  /// Multiple foreground controls with one paint-only live control.
  foregroundMultiMixed('foreground_multi_mixed'),

  /// Static foreground control above a fallback flight that repaints each tick.
  foregroundFallbackStatic('foreground_fallback_static'),

  /// Repainting foreground control above a fallback flight that repaints each
  /// tick.
  foregroundFallbackLive('foreground_fallback_live'),

  /// Retained Text whose watched destination continuously moves and resizes.
  watchText('watch_text'),

  /// Retained compound flight whose watched destination continuously moves and
  /// resizes.
  watchCompound('watch_compound'),

  /// Minimal custom flight whose watched destination continuously moves and
  /// resizes.
  watchCustom('watch_custom'),

  /// Watched Text whose destination stays fixed after its initial layout.
  watchStationary('watch_stationary'),

  /// The stationary Text workload without destination watching.
  watchStationaryControl('watch_stationary_control'),

  /// Twenty-four static snapshots inside a watched destination.
  watchSnapshotDense('watch_snapshot_dense'),

  /// Fixed snapshot pixels inside a destination whose geometry keeps changing.
  watchSnapshotGeometryOnly('watch_snapshot_geometry_only'),

  /// Twenty-four watched snapshots with coalesced in-flight pixel changes.
  watchSnapshotDynamic('watch_snapshot_dynamic'),

  /// A near-full-surface snapshot changing size and pixels on consecutive
  /// frames.
  watchSnapshotFullSurface('watch_snapshot_full_surface'),

  /// Nested snapshot boundaries using conservative automatic refreshes.
  watchSnapshotNestedFallback('watch_snapshot_nested_fallback'),

  /// Many unmatched resting endpoints moving under one animated ancestor.
  restingScroll('resting_scroll'),

  /// Raw ordinary descendants without a transition builder.
  rawDescendants('raw_descendants'),

  /// Raw ordinary descendants using a fade transition builder.
  rawDescendantsFade('raw_descendants_fade'),

  /// One live descendant inside a resizing surface.
  descendantLive('descendant_live'),

  /// One captured descendant inside a resizing surface.
  descendantSnapshot('descendant_snapshot'),

  /// One hidden descendant inside a resizing surface.
  descendantHide('descendant_hide'),

  /// Twenty-four sibling snapshot descendants inside one surface.
  descendantSnapshotDense('descendant_snapshot_dense'),

  /// Column flight with unmatched ordinary departing and arriving children.
  columnUnmatched('column_unmatched'),

  /// Hybrid Column flight with one keyed ordinary child whose captured size
  /// changes continuously.
  columnMatchedRawResize('column_matched_raw_resize'),

  /// Parent flight that holds four shorter nested Text flights at their
  /// destinations.
  nestedHold('nested_hold'),

  /// A 640 ms parent flight that holds a watched 160 ms Text flight while the
  /// receiving geometry continues moving.
  nestedWatchHold('nested_watch_hold'),

  /// Retained DecoratedBox flight that paints its decoration behind its child.
  decoratedBackground('decorated_background'),

  /// Retained DecoratedBox flight that paints its decoration in front of its
  /// child.
  decoratedForeground('decorated_foreground');

  const MorphBenchmarkScenario(this.id);

  /// Stable identifier accepted by `MORPH_SCENARIO` and emitted in benchmark
  /// JSON.
  final String id;

  /// Whether steady results must prove watched snapshot refresh invariants.
  bool get gatesWatchedSnapshotRefresh {
    return switch (this) {
      watchSnapshotDense ||
      watchSnapshotGeometryOnly ||
      watchSnapshotDynamic ||
      watchSnapshotFullSurface ||
      watchSnapshotNestedFallback => true,
      _ => false,
    };
  }

  /// Number of post-start snapshot mutation batches requested per transition.
  int get snapshotMutationBatches {
    return switch (this) {
      watchSnapshotGeometryOnly || watchSnapshotDynamic => 4,
      watchSnapshotFullSurface => 12,
      watchSnapshotNestedFallback => 8,
      _ => 0,
    };
  }

  /// Number of synchronous changes requested in each mutation batch.
  int get snapshotMutationsPerBatch {
    return switch (this) {
      watchSnapshotGeometryOnly || watchSnapshotDynamic => 3,
      watchSnapshotFullSurface || watchSnapshotNestedFallback => 1,
      _ => 0,
    };
  }

  /// Whether benchmark mutation batches change captured descendant pixels.
  bool get mutatesSnapshotPixels {
    return switch (this) {
      watchSnapshotDynamic => true,
      watchSnapshotFullSurface => true,
      watchSnapshotNestedFallback => true,
      _ => false,
    };
  }

  /// Whether benchmark mutation batches change destination geometry.
  bool get mutatesSnapshotGeometry {
    return switch (this) {
      watchSnapshotGeometryOnly => true,
      watchSnapshotDynamic => true,
      watchSnapshotFullSurface => true,
      _ => false,
    };
  }

  /// Whether nested boundaries require a conservative refresh each tick.
  bool get usesConservativeSnapshotFallback {
    return this == watchSnapshotNestedFallback;
  }

  /// Returns the stable child identity for one endpoint state.
  String endpointIdentity({
    required String child,
    required bool destination,
  }) {
    final state = destination ? 'destination' : 'source';
    return 'benchmark-$id-$child-$state';
  }

  /// Resolves one scenario identifier.
  static MorphBenchmarkScenario fromId(String id) {
    for (final scenario in values) {
      if (scenario.id == id) return scenario;
    }
    throw ArgumentError.value(
      id,
      'MORPH_SCENARIO',
      'must be one of: ${values.map((scenario) => scenario.id).join(', ')}',
    );
  }

  /// Resolves `all` or one stable scenario identifier.
  static List<MorphBenchmarkScenario> selectedFrom(String requested) {
    if (requested == 'all') return values;
    return <MorphBenchmarkScenario>[fromId(requested)];
  }

  /// Resolves the scenario used by the optional post-measurement soak.
  static MorphBenchmarkScenario soakTargetFor(String requested) {
    if (requested == 'all') return surface;
    return fromId(requested);
  }
}
