import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_log_validator.dart';
import '../../benchmark/morph/morph_benchmark_record_buffer.dart';

void main() {
  String buildLog({
    bool acceptancePassed = true,
    int frames = 150,
    String mode = 'profile',
    bool retried = false,
    List<String> scenarios = const <String>['text', 'surface'],
    int dynamicDirtyCapturePaints = 4,
    int dynamicTemporalImages = 4,
    int dynamicFinalCapturedGeneration = 22,
    int dynamicMaxPaintsPerFrame = 1,
    List<int> dynamicCapturedGenerations = const <int>[13, 16, 19, 22],
    int dynamicUnchangedCapturePaints = 0,
    int staticDirtyCapturePaints = 0,
    int staticTemporalImages = 0,
    List<int> fallbackCapturedGenerations = const <int>[
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
    ],
  }) {
    final records = <Map<String, Object?>>[
      <String, Object?>{
        'path': 'environment',
        'mode': mode,
        'renderer': 'impeller-vulkan',
        'refresh_rate_hz': 120.0,
        'scenarios': scenarios,
        'steady_trials': 2,
        'steady_frames_per_trial': frames,
      },
    ];
    for (final scenario in scenarios) {
      for (var trial = 1; trial <= 2; trial += 1) {
        if (retried && scenario == scenarios.first && trial == 1) {
          records.add(<String, Object?>{
            'path': '$scenario.steady.trial_1.invalid.attempt_1',
            'scenario': scenario,
            'phase': 'steady',
            'trial': 1,
            'attempt': 1,
            'valid': false,
            'invalid_direction': 'forward',
            'invalid_reasons': <String>['view_focus_changed'],
            'retrying': true,
          });
        }
        for (final direction in const <String>['forward', 'reverse']) {
          final isFirstScenario = scenario == scenarios.first;
          final isFirstTrial = trial == 1;
          final isRetriedTrial = retried && isFirstScenario && isFirstTrial;
          final attempt = isRetriedTrial ? 2 : 1;
          final record = <String, Object?>{
            'path': '$scenario.steady.$direction.trial_$trial',
            'scenario': scenario,
            'phase': 'steady',
            'direction': direction,
            'trial': trial,
            'attempt': attempt,
            'retried': attempt > 1,
            'transitions': 1,
            'frames': frames,
            'work_p99_within_budget': true,
            'gate': true,
          };
          if (scenario.startsWith('watch_snapshot_')) {
            var mutationBatches = 0;
            var mutationsPerBatch = 0;
            var requestedGeneration = 10;
            var expectedGenerations = <int>[];
            var dirtyCapturePaints = 0;
            var capturedGenerations = <int>[];
            var unchangedCapturePaints = 0;
            var finalCapturedGeneration = -1;
            var dirtyMaxPaintsPerFrame = 0;
            const cleanMaxPaints = 0;
            var temporalImages = 0;
            var captureExpectation = 'exact';
            if (scenario == 'watch_snapshot_geometry_only') {
              mutationBatches = 4;
              mutationsPerBatch = 3;
              requestedGeneration = 22;
            }
            if (scenario == 'watch_snapshot_dynamic') {
              mutationBatches = 4;
              mutationsPerBatch = 3;
              requestedGeneration = 22;
              expectedGenerations = const <int>[13, 16, 19, 22];
              dirtyCapturePaints = dynamicDirtyCapturePaints;
              capturedGenerations = dynamicCapturedGenerations;
              unchangedCapturePaints = dynamicUnchangedCapturePaints;
              finalCapturedGeneration = dynamicFinalCapturedGeneration;
              dirtyMaxPaintsPerFrame = dynamicMaxPaintsPerFrame;
              temporalImages = dynamicTemporalImages;
            }
            if (scenario == 'watch_snapshot_full_surface') {
              mutationBatches = 12;
              mutationsPerBatch = 1;
              requestedGeneration = 22;
              expectedGenerations = const <int>[
                11,
                12,
                13,
                14,
                15,
                16,
                17,
                18,
                19,
                20,
                21,
                22,
              ];
              dirtyCapturePaints = 12;
              capturedGenerations = expectedGenerations;
              finalCapturedGeneration = 22;
              dirtyMaxPaintsPerFrame = 1;
              temporalImages = 12;
            }
            if (scenario == 'watch_snapshot_nested_fallback') {
              mutationBatches = 8;
              mutationsPerBatch = 1;
              requestedGeneration = 18;
              expectedGenerations = const <int>[
                11,
                12,
                13,
                14,
                15,
                16,
                17,
                18,
              ];
              dirtyCapturePaints = 8;
              capturedGenerations = fallbackCapturedGenerations;
              finalCapturedGeneration = 18;
              dirtyMaxPaintsPerFrame = 1;
              temporalImages = 8;
              captureExpectation = 'continuous_fallback';
            }
            if (scenario == 'watch_snapshot_dense') {
              dirtyCapturePaints = staticDirtyCapturePaints;
              temporalImages = staticTemporalImages;
            }
            final actualSequence = capturedGenerations.join(',');
            final expectedSequence = expectedGenerations.join(',');
            final generationSequencePass = actualSequence == expectedSequence;
            final unchangedProbePass = unchangedCapturePaints == 0;
            final expectedPaints = expectedGenerations.length;
            final dirtyCapturePass = dirtyCapturePaints == expectedPaints;
            var expectedFinal = -1;
            if (expectedGenerations.isNotEmpty) {
              expectedFinal = expectedGenerations.last;
            }
            final expectedDirtyRate = expectedGenerations.isEmpty ? 0 : 1;
            final structuralPass =
                generationSequencePass &&
                unchangedProbePass &&
                dirtyCapturePass &&
                finalCapturedGeneration == expectedFinal &&
                dirtyMaxPaintsPerFrame == expectedDirtyRate &&
                cleanMaxPaints == 0;
            record
              ..['snapshot_refreshes'] = <Map<String, Object?>>[
                <String, Object?>{
                  'mutation_batches': mutationBatches,
                  'mutations_per_batch': mutationsPerBatch,
                  'requested_generation_start': 10,
                  'requested_generation': requestedGeneration,
                  'capture_expectation': captureExpectation,
                  'expected_captured_generations': expectedGenerations,
                  'dirty_capture_paints': dirtyCapturePaints,
                  'dirty_captured_generations': capturedGenerations,
                  'dirty_final_captured_generation': finalCapturedGeneration,
                  'dirty_max_capture_paints_per_frame': dirtyMaxPaintsPerFrame,
                  'unchanged_capture_paints': unchangedCapturePaints,
                  'unchanged_captured_generations': <int>[],
                  'unchanged_max_capture_paints_per_frame': cleanMaxPaints,
                  'temporal_ui_images_created': temporalImages,
                  'generation_sequence_passed': generationSequencePass,
                  'unchanged_probe_passed': unchangedProbePass,
                  'invariants_passed': structuralPass,
                },
              ]
              ..['snapshot_invariants_passed'] = structuralPass;
          }
          records.add(record);
        }
      }
    }
    var failedSteadyPaths = <String>[];
    if (!acceptancePassed) {
      failedSteadyPaths = <String>['text.steady.forward.trial_1'];
    }
    records.add(<String, Object?>{
      'path': 'acceptance',
      'passed': acceptancePassed,
      'enforced': true,
      'failed_steady_paths': failedSteadyPaths,
      'steady_trials': 2,
      'steady_frames_per_trial': frames,
      'invalid_trial_attempts': retried ? 1 : 0,
      'retried_trials': retried ? 1 : 0,
    });
    return records
        .map(
          (record) => 'flutter: MORPH_BENCHMARK ${jsonEncode(record)}',
        )
        .join('\n');
  }

  MorphBenchmarkLogValidator validator({
    List<String> scenarios = const <String>['text', 'surface'],
  }) {
    return MorphBenchmarkLogValidator(
      expectedScenarioIds: scenarios,
      requireBudgetPass: true,
      requireEnforcedBudget: true,
    );
  }

  group('MorphBenchmarkLogValidator', () {
    test('when a complete host log passes, it should accept it', () {
      final validation = validator().validate(buildLog());

      expect(validation.passed, isTrue);
    });

    test(
      'when application acceptance is false despite shell success, '
      'it should reject the log',
      () {
        final validation = validator().validate(
          buildLog(acceptancePassed: false),
        );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a complete record is emitted in bounded chunks, '
      'it should reconstruct and validate it',
      () {
        final ordinaryLog = buildLog();
        final acceptanceLine = ordinaryLog.split('\n').last;
        final acceptance = Map<String, Object>.from(
          jsonDecode(
            acceptanceLine.substring(
              acceptanceLine.indexOf('{'),
            ),
          ) as Map<String, Object?>,
        );
        acceptance['diagnostic_padding'] = List<String>.filled(
          5000,
          'x',
        ).join();
        final emitted = <String>[];
        MorphBenchmarkRecordBuffer(emitted.add)
          ..add(acceptance)
          ..flush();
        final lines = ordinaryLog.split('\n');
        final withoutAcceptance = lines.take(lines.length - 1).join('\n');
        final chunkedLog = <String>[
          withoutAcceptance,
          ...emitted.map((line) => 'flutter: $line'),
        ].join('\n');

        final validation = validator().validate(chunkedLog);

        expect(validation.passed, isTrue);
      },
    );

    test('when required records are missing, it should reject the log', () {
      final validation = validator().validate('flutter run exited normally');

      expect(validation.passed, isFalse);
    });

    test(
      'when the application mode is not profile, it should reject the log',
      () {
        final validation = validator().validate(buildLog(mode: 'debug'));

        expect(validation.passed, isFalse);
      },
    );

    test('when the exact scenario set differs, it should reject the log', () {
      final validation = validator().validate(
        buildLog(scenarios: const <String>['text']),
      );

      expect(validation.passed, isFalse);
    });

    test('when a steady gate has too few frames, it should reject the log', () {
      final validation = validator().validate(buildLog(frames: 149));

      expect(validation.passed, isFalse);
    });

    test(
      'when an interrupted trial succeeds on retry, '
      'it should surface both events',
      () {
        final validation = validator().validate(buildLog(retried: true));

        expect(
          (
            passed: validation.passed,
            invalidSurfaced: validation.summary.contains(
              'Invalid attempt details:',
            ),
            retrySurfaced: validation.summary.contains(
              'Completed retry details:',
            ),
          ),
          (passed: true, invalidSurfaced: true, retrySurfaced: true),
        );
      },
    );

    test(
      'when dynamic watched snapshot refreshes match every mutation batch, '
      'it should accept the structural gate',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_dynamic'],
            ).validate(
              buildLog(scenarios: const <String>['watch_snapshot_dynamic']),
            );

        expect(validation.passed, isTrue);
      },
    );

    test(
      'when temporal image creation differs from capture paints, '
      'it should remain diagnostic',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_dynamic'],
            ).validate(
              buildLog(
                scenarios: const <String>['watch_snapshot_dynamic'],
                dynamicTemporalImages: 3,
              ),
            );

        expect(validation.passed, isTrue);
      },
    );

    test(
      'when one dynamic mutation batch does not paint a capture, '
      'it should reject the structural gate',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_dynamic'],
            ).validate(
              buildLog(
                scenarios: const <String>['watch_snapshot_dynamic'],
                dynamicDirtyCapturePaints: 3,
              ),
            );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a dynamic watched snapshot captures a stale generation, '
      'it should reject the structural gate',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_dynamic'],
            ).validate(
              buildLog(
                scenarios: const <String>['watch_snapshot_dynamic'],
                dynamicFinalCapturedGeneration: 19,
              ),
            );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a dynamic watched snapshot skips an intermediate generation, '
      'it should reject the structural gate',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_dynamic'],
            ).validate(
              buildLog(
                scenarios: const <String>['watch_snapshot_dynamic'],
                dynamicCapturedGenerations: const <int>[13, 13, 19, 22],
              ),
            );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a nested fallback reports intermediate generations out of order, '
      'it should reject the structural gate',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_nested_fallback'],
            ).validate(
              buildLog(
                scenarios: const <String>['watch_snapshot_nested_fallback'],
                fallbackCapturedGenerations: const <int>[
                  11,
                  13,
                  12,
                  14,
                  15,
                  16,
                  17,
                  18,
                ],
              ),
            );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a dynamic watched snapshot repaints an unchanged descendant, '
      'it should reject the structural gate',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_dynamic'],
            ).validate(
              buildLog(
                scenarios: const <String>['watch_snapshot_dynamic'],
                dynamicUnchangedCapturePaints: 1,
              ),
            );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a dynamic watched snapshot paints twice in one frame, '
      'it should reject the structural gate',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_dynamic'],
            ).validate(
              buildLog(
                scenarios: const <String>['watch_snapshot_dynamic'],
                dynamicMaxPaintsPerFrame: 2,
              ),
            );

        expect(validation.passed, isFalse);
      },
    );

    test(
      'when a static watched snapshot refreshes after onStart, '
      'it should reject the structural gate',
      () {
        final validation =
            validator(
              scenarios: const <String>['watch_snapshot_dense'],
            ).validate(
              buildLog(
                scenarios: const <String>['watch_snapshot_dense'],
                staticDirtyCapturePaints: 1,
              ),
            );

        expect(validation.passed, isFalse);
      },
    );

    for (final scenario in const <String>[
      'watch_snapshot_geometry_only',
      'watch_snapshot_full_surface',
      'watch_snapshot_nested_fallback',
    ]) {
      test(
        'when $scenario reports its expected paints, '
        'it should accept the structural gate',
        () {
          final validation = validator(
            scenarios: <String>[scenario],
          ).validate(buildLog(scenarios: <String>[scenario]));

          expect(validation.passed, isTrue);
        },
      );
    }
  });
}
