import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'device_display_model_test_process.dart';

void main() {
  group('device display model trainer', () {
    test('when candidates can fit grouped folds, it should execute every declared model', () async {
      final temporaryDirectory = Directory.systemTemp.createTempSync(
        'omf-display-trainer-test-',
      );
      addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
      final manifestFile = File('${temporaryDirectory.path}/manifest.json');

      final result = await DeviceDisplayModelTestProcess.run([
        'dart',
        'run',
        'tool/device_display_model/device_display_model.dart',
        'train',
        '--corpus',
        'test/tool/device_display_model/fixtures/corpus.json',
        '--output',
        manifestFile.path,
      ]);
      final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
      final platforms = manifest['platforms']! as Map<String, Object?>;
      final android = platforms['android']! as Map<String, Object?>;
      final scores = android['candidateScores']! as List<Object?>;
      final classification = android['classification']! as Map<String, Object?>;
      final featureSchema = android['featureSchema']! as Map<String, Object?>;
      final heads = android['headModels']! as Map<String, Object?>;
      final prior = android['prior']! as Map<String, Object?>;
      final support = android['support']! as Map<String, Object?>;
      final eligible = scores
          .map((value) => value! as Map<String, Object?>)
          .where((score) => score['eligible'] == true)
          .map((score) => score['candidate'])
          .toList();

      expect(
        <Object?>[
          result.exitCode,
          android['selectedCandidate'],
          android['predictionPipeline'],
          (heads['top']! as Map<String, Object?>)['kind'],
          (heads['bottom']! as Map<String, Object?>)['kind'],
          classification['squareRecordCount'],
          classification['isFitted'],
          prior['candidate'],
          support['modelBlendWeight'],
          support['distanceTransitionScale'],
          support['disagreementTransitionScale'],
          support['innerPriorCandidates'],
          android['selectionOrder'],
          eligible,
          scores.take(4).every((value) {
            final score = value! as Map<String, Object?>;
            return score['scoringPipeline'] == 'fold_local_raw_bounded_formula_v1' &&
                score['challengerCandidate'] == null;
          }),
          scores.skip(4).every((value) {
            final score = value! as Map<String, Object?>;
            return score['scoringPipeline'] == 'fold_local_distance_disagreement_gate_prior_v1' &&
                score['challengerCandidate'] is String;
          }),
          featureSchema['names'],
        ],
        <Object?>[
          0,
          'spline_gam',
          'distance_disagreement_gate_prior_v1',
          'spline_gam',
          'spline_gam',
          1,
          true,
          'shortest_side_formula',
          0.0,
          0.25,
          0.25,
          <Object?>['shortest_side_formula'],
          <Object?>[
            'worstRegimeBootstrapUpperLogicalP95',
            'worstRegimeMacroLogicalPixelMae',
            'logicalPixelMaximumAbsoluteError',
            'generatedModelBytes',
            'inferenceOperationCount',
            'candidateOrder',
          ],
          <Object?>[
            'zero_baseline',
            'safe_inset_baseline',
            'platform_median_logical_radius',
            'shortest_side_formula',
            'robust_quadratic_regression',
            'spline_gam',
            'shallow_boosted_tree',
            'constrained_blend',
          ],
          true,
          true,
          <Object?>[
            'logDisplayAspectRatio',
            'logPhysicalShortSide',
            'logLogicalShortSide',
            'logDevicePixelRatio',
            'viewportCoverage',
            'maximumViewPaddingDiameterFraction',
            'naturalTopPaddingDiameterFraction',
            'naturalBottomPaddingDiameterFraction',
            'maximumGestureInsetDiameterFraction',
            'cutoutWidthFraction',
            'cutoutHeightFraction',
            'cutoutCountFraction',
            'devicePixelRatioMissing',
            'viewSizeMissing',
            'viewPaddingMissing',
            'systemGestureInsetsMissing',
            'displayCutoutMissing',
          ],
        ],
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'when a normalized label has no DPR, it should train with it but score '
      'only logical-pixel labels',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-normalized-only-trainer-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final corpus = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/corpus.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final records = corpus['records']! as List<Object?>;
        (records.first! as Map<String, Object?>)['devicePixelRatio'] = null;
        final corpusFile = File('${temporaryDirectory.path}/corpus.json')..writeAsStringSync(jsonEncode(corpus));
        final manifestFile = File('${temporaryDirectory.path}/manifest.json');

        final result = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'train',
          '--corpus',
          corpusFile.path,
          '--output',
          manifestFile.path,
        ]);
        final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
        final android = (manifest['platforms']! as Map<String, Object?>)['android']! as Map<String, Object?>;

        expect(
          <Object?>[
            result.exitCode,
            android['labeledRecordCount'],
            android['logicalScoringRecordCount'],
            android['validationGroupCount'],
            (android['candidateScores']! as List<Object?>).every(
              (value) => (value! as Map<String, Object?>)['eligible'] == true,
            ),
          ],
          <Object?>[0, 6, 5, 5, true],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when a baseline has the lowest grouped score, it should keep it report-only and select a structured candidate',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-selection-candidate-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final corpus = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/corpus.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        for (final value in corpus['records']! as List<Object?>) {
          final record = value! as Map<String, Object?>;
          record['topRadiusPhysical'] = 0.0;
          record['bottomRadiusPhysical'] = 0.0;
          record['cornerClassification'] = 'square';
        }
        final corpusFile = File('${temporaryDirectory.path}/corpus.json')..writeAsStringSync(jsonEncode(corpus));
        final manifestFile = File('${temporaryDirectory.path}/manifest.json');

        final result = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'train',
          '--corpus',
          corpusFile.path,
          '--output',
          manifestFile.path,
        ]);
        final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
        final android = (manifest['platforms']! as Map<String, Object?>)['android']! as Map<String, Object?>;
        final scores = (android['candidateScores']! as List<Object?>).cast<Map<String, Object?>>();
        final zero = scores.singleWhere(
          (score) => score['candidate'] == 'zero_baseline',
        );

        expect(
          <Object?>[
            result.exitCode,
            const <String>{
              'robust_quadratic_regression',
              'spline_gam',
              'shallow_boosted_tree',
              'constrained_blend',
            }.contains(android['selectedCandidate']),
            zero['selectionEligible'],
            zero['worstRegimeBootstrapUpperLogicalP95'],
            scores
                .skip(4)
                .every(
                  (score) => score['selectionEligible'] == true,
                ),
          ],
          <Object?>[0, true, false, 0, true],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when inner held-out labels change the prior-family winner, it should select each calibration prior from inner training only',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-nested-prior-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final corpus = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/corpus.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final records = (corpus['records']! as List<Object?>).take(2).toList();
        final corpusFile = File('${temporaryDirectory.path}/corpus.json')
          ..writeAsStringSync(
            jsonEncode(<String, Object?>{
              ...corpus,
              'records': records,
            }),
          );
        final manifestFile = File('${temporaryDirectory.path}/manifest.json');

        final result = await DeviceDisplayModelTestProcess.run(<String>[
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'train',
          '--corpus',
          corpusFile.path,
          '--output',
          manifestFile.path,
        ]);
        final android =
            ((jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>)['platforms']!
                    as Map<String, Object?>)['android']!
                as Map<String, Object?>;
        final prior = android['prior']! as Map<String, Object?>;
        final support = android['support']! as Map<String, Object?>;

        expect(
          <Object?>[
            result.exitCode,
            prior['candidate'],
            support['innerPriorCandidates'],
          ],
          <Object?>[
            0,
            'shortest_side_formula',
            <Object?>['safe_inset_baseline'],
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when observable collision hashes are absent, it should keep unrelated families separate',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-null-collision-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final corpus = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/corpus.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final records = corpus['records']! as List<Object?>;
        for (var index = 0; index < records.length; index += 1) {
          final record = records[index]! as Map<String, Object?>;
          record['familyGroupHash'] = 'family-$index';
          record['observableCollisionGroupHash'] = null;
          record['geometryCollisionGroupHash'] = null;
          record['validationGroup'] = null;
        }
        final corpusFile = File('${temporaryDirectory.path}/corpus.json')..writeAsStringSync(jsonEncode(corpus));
        final manifestFile = File('${temporaryDirectory.path}/manifest.json');

        final result = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'train',
          '--corpus',
          corpusFile.path,
          '--output',
          manifestFile.path,
        ]);
        final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
        final android = (manifest['platforms']! as Map<String, Object?>)['android']! as Map<String, Object?>;

        expect(
          <Object?>[result.exitCode, android['validationGroupCount']],
          <Object?>[0, records.length],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when skin and connected sources share display geometry, it should keep them in one leakage group',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-cross-source-geometry-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final corpus = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/corpus.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final records = corpus['records']! as List<Object?>;
        for (var index = 0; index < records.length; index += 1) {
          final record = records[index]! as Map<String, Object?>;
          record['familyGroupHash'] = 'source-family-$index';
          record['observableCollisionGroupHash'] = 'source-observable-$index';
          record['geometryCollisionGroupHash'] = index < 2 ? 'shared-cross-source-geometry' : 'source-geometry-$index';
          record['sourceKind'] = index == 0
              ? 'android_sdk_skin_avd_join'
              : index == 1
              ? 'android_api31_window_insets'
              : record['sourceKind'];
        }
        final corpusFile = File('${temporaryDirectory.path}/corpus.json')..writeAsStringSync(jsonEncode(corpus));
        final manifestFile = File(
          '${temporaryDirectory.path}/manifest.json',
        );

        final result = await DeviceDisplayModelTestProcess.run(<String>[
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'train',
          '--corpus',
          corpusFile.path,
          '--output',
          manifestFile.path,
        ]);
        final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
        final android = (manifest['platforms']! as Map<String, Object?>)['android']! as Map<String, Object?>;

        expect(
          <Object?>[result.exitCode, android['validationGroupCount']],
          <Object?>[0, records.length - 1],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when one leakage group lacks generation metadata, it should exclude that group and execute trustworthy holdouts',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-metadata-subset-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final corpus = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/corpus.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final records = corpus['records']! as List<Object?>;
        for (var index = 0; index < records.length; index += 1) {
          final record = records[index]! as Map<String, Object?>;
          record['familyGroupHash'] = 'family-$index';
          record['observableCollisionGroupHash'] = 'observable-$index';
          record['geometryCollisionGroupHash'] = 'geometry-$index';
          record['validationGroup'] = 'validation-$index';
          record['maskCollisionGroupHash'] = index < 2
              ? 'shared-metadata-mask'
              : index == 2 || index == records.length - 1
              ? 'shared-newest-with-missing-mask'
              : null;
          record['oemGroupHash'] = 'oem-${index % 2}';
          record['generationGroupHash'] = index == records.length - 1 ? null : 'generation-${index % 3}';
          record['chronologyRank'] = index == records.length - 1 ? null : index % 3;
        }
        final corpusFile = File('${temporaryDirectory.path}/corpus.json')..writeAsStringSync(jsonEncode(corpus));
        final manifestFile = File(
          '${temporaryDirectory.path}/manifest.json',
        );

        final result = await DeviceDisplayModelTestProcess.run(<String>[
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'train',
          '--corpus',
          corpusFile.path,
          '--output',
          manifestFile.path,
        ]);
        final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
        final android = (manifest['platforms']! as Map<String, Object?>)['android']! as Map<String, Object?>;
        final holdouts = android['holdouts']! as Map<String, Object?>;
        final generation = holdouts['leaveGenerationOut']! as Map<String, Object?>;
        final newest = holdouts['newestGeneration']! as Map<String, Object?>;
        final generationMetrics = generation['metrics']! as Map<String, Object?>;
        final newestMetrics = newest['metrics']! as Map<String, Object?>;

        expect(
          <Object?>[
            result.exitCode,
            generation['status'],
            generation['eligibleLeakageGroupCount'],
            generation['excludedLeakageGroupCount'],
            generationMetrics['logicalPixelObservationCount'],
            generationMetrics['logicalPixelLeakageGroupCount'],
            newest['status'],
            newest['eligibleLeakageGroupCount'],
            newest['excludedLeakageGroupCount'],
            newestMetrics['logicalPixelObservationCount'],
            newestMetrics['logicalPixelLeakageGroupCount'],
          ],
          <Object?>[
            0,
            'executed',
            records.length - 2,
            0,
            10,
            4,
            'executed',
            records.length - 2,
            0,
            2,
            1,
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when the Flutter safe-inset heuristic is compared, it should use top padding and its threshold per observation',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-safe-inset-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        Map<String, Object?> record({
          required String platform,
          required String family,
          required String observation,
          required double width,
          required double height,
          required double left,
          required double top,
          required double right,
          required double bottom,
          required double topRadius,
          required double bottomRadius,
        }) => <String, Object?>{
          'platform': platform,
          'sourceKind': 'test_exact',
          'physicalWidth': width,
          'physicalHeight': height,
          'viewPhysicalWidth': width,
          'viewPhysicalHeight': height,
          'devicePixelRatio': 2.0,
          'viewPaddingLeftPhysical': left,
          'viewPaddingTopPhysical': top,
          'viewPaddingRightPhysical': right,
          'viewPaddingBottomPhysical': bottom,
          'familyGroupHash': family,
          'generationGroupHash': '$platform-generation',
          'oemGroupHash': '$platform-oem',
          'observableCollisionGroupHash': observation,
          'chronologyRank': 1,
          'cornerClassification': 'rounded',
          'topRadiusPhysical': topRadius,
          'bottomRadiusPhysical': bottomRadius,
        };
        final corpus = <String, Object?>{
          'records': <Object?>[
            record(
              platform: 'android',
              family: 'android-family-a',
              observation: 'android-observation-a1',
              width: 2000,
              height: 1000,
              left: 100,
              top: 300,
              right: 50,
              bottom: 250,
              topRadius: 270,
              bottomRadius: 270,
            ),
            record(
              platform: 'android',
              family: 'android-family-a',
              observation: 'android-observation-a2',
              width: 2000,
              height: 1000,
              left: 120,
              top: 350,
              right: 40,
              bottom: 280,
              topRadius: 315,
              bottomRadius: 315,
            ),
            record(
              platform: 'android',
              family: 'android-family-b',
              observation: 'android-observation-b',
              width: 2200,
              height: 1000,
              left: 80,
              top: 320,
              right: 60,
              bottom: 260,
              topRadius: 288,
              bottomRadius: 288,
            ),
            record(
              platform: 'ios',
              family: 'ios-family-a',
              observation: 'ios-observation-a1',
              width: 1000,
              height: 2000,
              left: 100,
              top: 20,
              right: 30,
              bottom: 10,
              topRadius: 0,
              bottomRadius: 0,
            ),
            record(
              platform: 'ios',
              family: 'ios-family-a',
              observation: 'ios-observation-a2',
              width: 1000,
              height: 2000,
              left: 40,
              top: 120,
              right: 30,
              bottom: 10,
              topRadius: 108,
              bottomRadius: 108,
            ),
            record(
              platform: 'ios',
              family: 'ios-family-b',
              observation: 'ios-observation-b',
              width: 1000,
              height: 2200,
              left: 20,
              top: 80,
              right: 10,
              bottom: 30,
              topRadius: 72,
              bottomRadius: 72,
            ),
          ],
        };
        final corpusFile = File('${temporaryDirectory.path}/corpus.json')..writeAsStringSync(jsonEncode(corpus));
        final manifestFile = File('${temporaryDirectory.path}/manifest.json');

        final result = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'train',
          '--corpus',
          corpusFile.path,
          '--output',
          manifestFile.path,
        ]);
        final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
        final platforms = manifest['platforms']! as Map<String, Object?>;
        double safeInsetMaximum(String platform) {
          final platformModel = platforms[platform]! as Map<String, Object?>;
          final scores = platformModel['candidateScores']! as List<Object?>;
          final safeInset = scores.cast<Map<String, Object?>>().singleWhere(
            (score) => score['candidate'] == 'safe_inset_baseline',
          );
          final standalone = safeInset['standaloneComparator']! as Map<String, Object?>;
          final metrics = standalone['metrics']! as Map<String, Object?>;
          return (metrics['logicalPixelMaximumAbsoluteError']! as num).toDouble();
        }

        expect(
          <Object?>[
            result.exitCode,
            safeInsetMaximum('android'),
            safeInsetMaximum('ios'),
          ],
          <Object?>[0, closeTo(0, 0.000001), closeTo(0, 0.000001)],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
