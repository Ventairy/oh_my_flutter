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
            'watch_text',
            'watch_compound',
            'watch_custom',
            'watch_stationary',
            'watch_stationary_control',
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
  });
}
