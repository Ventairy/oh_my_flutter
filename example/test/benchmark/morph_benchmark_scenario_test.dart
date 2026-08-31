import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_scenario.dart';

void main() {
  group('MorphBenchmarkScenario', () {
    test(
      'when all scenarios are selected, '
      'it should preserve the declared order',
      () {
        final ids = MorphBenchmarkScenario.selectedFrom(
          'all',
        ).map((scenario) => scenario.id);
        expect(
          ids,
          <String>[
            'text',
            'column',
            'surface',
            'foreground_static',
            'foreground_live',
            'foreground_multi_static',
            'foreground_multi_mixed',
            'foreground_fallback_static',
            'foreground_fallback_live',
            'watch_text',
            'watch_compound',
            'watch_custom',
            'watch_stationary',
            'watch_stationary_control',
            'watch_snapshot_dense',
            'watch_snapshot_geometry_only',
            'watch_snapshot_dynamic',
            'watch_snapshot_full_surface',
            'watch_snapshot_nested_fallback',
            'resting_scroll',
            'raw_descendants',
            'raw_descendants_fade',
            'descendant_live',
            'descendant_snapshot',
            'descendant_hide',
            'descendant_snapshot_dense',
            'column_unmatched',
            'column_matched_raw_resize',
            'nested_hold',
            'nested_watch_hold',
            'decorated_background',
            'decorated_foreground',
          ],
        );
      },
    );

    for (final scenario in MorphBenchmarkScenario.values) {
      test(
        'when ${scenario.id} is selected, '
        'it should resolve that scenario',
        () {
          expect(
            MorphBenchmarkScenario.selectedFrom(scenario.id),
            <MorphBenchmarkScenario>[scenario],
          );
        },
      );
    }

    test(
      'when an unknown scenario is selected, '
      'it should reject the identifier',
      () {
        expect(
          () => MorphBenchmarkScenario.selectedFrom('unknown'),
          throwsArgumentError,
        );
      },
    );

    test(
      'when all scenarios are soaked, it should select the surface',
      () {
        expect(
          MorphBenchmarkScenario.soakTargetFor('all'),
          MorphBenchmarkScenario.surface,
        );
      },
    );

    test(
      'when one scenario is soaked, it should preserve that scenario',
      () {
        expect(
          MorphBenchmarkScenario.soakTargetFor('column_unmatched'),
          MorphBenchmarkScenario.columnUnmatched,
        );
      },
    );

    test(
      'when the same endpoint state rebuilds, '
      'it should preserve its child identity',
      () {
        final first = MorphBenchmarkScenario.text.endpointIdentity(
          child: 'title',
          destination: false,
        );
        final second = MorphBenchmarkScenario.text.endpointIdentity(
          child: 'title',
          destination: false,
        );
        expect(identical(first, second) || first == second, isTrue);
      },
    );

    test(
      'when the endpoint state changes, '
      'it should change its child identity',
      () {
        final source = MorphBenchmarkScenario.text.endpointIdentity(
          child: 'title',
          destination: false,
        );
        final destination = MorphBenchmarkScenario.text.endpointIdentity(
          child: 'title',
          destination: true,
        );
        expect(source == destination, isFalse);
      },
    );

    test(
      'when the dynamic watched snapshot scenario is inspected, '
      'it should declare four coalesced mutation batches',
      () {
        const scenario = MorphBenchmarkScenario.watchSnapshotDynamic;
        expect(
          (
            scenario.gatesWatchedSnapshotRefresh,
            scenario.snapshotMutationBatches,
            scenario.snapshotMutationsPerBatch,
            scenario.mutatesSnapshotPixels,
            scenario.mutatesSnapshotGeometry,
            scenario.usesConservativeSnapshotFallback,
          ),
          (true, 4, 3, true, true, false),
        );
      },
    );

    test(
      'when the geometry-only watched snapshot scenario is inspected, '
      'it should mutate geometry without requesting new pixels',
      () {
        const scenario = MorphBenchmarkScenario.watchSnapshotGeometryOnly;
        expect(
          (
            scenario.gatesWatchedSnapshotRefresh,
            scenario.snapshotMutationBatches,
            scenario.snapshotMutationsPerBatch,
            scenario.mutatesSnapshotPixels,
            scenario.mutatesSnapshotGeometry,
          ),
          (true, 4, 3, false, true),
        );
      },
    );

    test(
      'when the full-surface watched snapshot scenario is inspected, '
      'it should request twelve consecutive-frame refreshes',
      () {
        const scenario = MorphBenchmarkScenario.watchSnapshotFullSurface;
        expect(
          (
            scenario.snapshotMutationBatches,
            scenario.snapshotMutationsPerBatch,
            scenario.mutatesSnapshotPixels,
            scenario.mutatesSnapshotGeometry,
          ),
          (12, 1, true, true),
        );
      },
    );

    test(
      'when the nested fallback watched snapshot scenario is inspected, '
      'it should declare independent pixel changes without a signal',
      () {
        const scenario = MorphBenchmarkScenario.watchSnapshotNestedFallback;
        expect(
          (
            scenario.gatesWatchedSnapshotRefresh,
            scenario.snapshotMutationBatches,
            scenario.snapshotMutationsPerBatch,
            scenario.mutatesSnapshotPixels,
            scenario.mutatesSnapshotGeometry,
            scenario.usesConservativeSnapshotFallback,
          ),
          (true, 8, 1, true, false, true),
        );
      },
    );

    test(
      'when the static watched snapshot scenario is inspected, '
      'it should require no post-start mutation batches',
      () {
        const scenario = MorphBenchmarkScenario.watchSnapshotDense;
        expect(
          (
            scenario.gatesWatchedSnapshotRefresh,
            scenario.snapshotMutationBatches,
          ),
          (true, 0),
        );
      },
    );
  });
}
