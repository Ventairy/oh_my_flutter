/// Scenario exercised by the Morph profile benchmark.
enum MorphBenchmarkScenario {
  /// Retained standalone Text flight.
  text('text'),

  /// Retained four-Text Column flight.
  column('column'),

  /// Retained decorated Container flight.
  surface('surface'),

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
