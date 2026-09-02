import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/device_display_model/device_display_model.dart';
import 'device_display_model_test_process.dart';

void main() {
  group('device display model pipeline', () {
    test(
      'when orientation features are built, it should derive them from the full display',
      () {
        final runtimeSource = File(
          'lib/src/device/device_display/estimator/device_display_estimator.dart',
        ).readAsStringSync();

        expect(
          <Object?>[
            RegExp(
              r'metrics\.displaySize\.width > metrics\.displaySize\.height',
            ).allMatches(runtimeSource).length,
            runtimeSource.contains(
              'metrics.viewSize.width > metrics.viewSize.height',
            ),
          ],
          <Object?>[1, false],
        );
      },
    );

    test(
      'when iOS lacks Flutter gesture and cutout evidence, it should align runtime missing features with training',
      () {
        final runtimeSource = File(
          'lib/src/device/device_display/estimator/device_display_estimator.dart',
        ).readAsStringSync();
        final trainingSource = File(
          'tool/device_display_model/src/device_display_model_models.dart',
        ).readAsStringSync();

        expect(
          <bool>[
            RegExp(
              r"'displayCutoutMissing',\s*\]",
            ).hasMatch(trainingSource),
            RegExp(
              r'2 \* _maximumEdge\(isIos \? EdgeInsets\.zero : '
              r'metrics\.systemGestureInsets\)',
            ).hasMatch(runtimeSource),
            runtimeSource.contains(
              '(isIos ? 0.0 : metrics.displayCutoutCount / 4).clamp(0, 1)',
            ),
            RegExp(
              r'if \(isIos\) 1\.0 else 0\.0,\s*'
              r'if \(isIos\) 1\.0 else 0\.0,\s*\]',
            ).hasMatch(runtimeSource),
          ],
          <bool>[true, true, true, true],
        );
      },
    );

    test(
      'when calibrated support is zero, it should reproduce the per-input robust prior including square output',
      () {
        final schema = <String, Object?>{
          'medians': <Object?>[0.0],
          'madScales': <Object?>[1.0],
          'distanceInner': 0.0,
          'distanceOuter': 1.0,
        };
        final gate = <String, Object?>{
          'kind': 'constant_logistic',
          'fitted': false,
          'priorProbability': 0.0,
          'threshold': 0.5,
          'intercept': 0.0,
          'coefficients': <Object?>[],
        };
        double predict(double safeInset) => DeviceDisplayModelPipeline.predict(
          selectedModel: const <String, Object?>{
            'kind': 'median',
            'intercept': 0.8,
          },
          challengerModel: null,
          priorModel: const <String, Object?>{'kind': 'safe_inset'},
          gate: gate,
          featureSchema: schema,
          disagreement: const <String, Object?>{
            'available': false,
          },
          features: const <double>[0],
          safeInsetDiameter: safeInset,
          logicalRadiusScale: 100,
          modelBlendWeight: 0,
          distanceTransitionScale: 1,
          disagreementTransitionScale: 1,
        );

        expect(
          <double>[predict(0.3), predict(0)],
          <Matcher>[closeTo(0.3, 0.0000001), closeTo(0, 0.0000001)],
        );
      },
    );

    test(
      'when a fixed manifest is generated, it should match the offline full pipeline for both platforms',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-pipeline-parity-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final schema = <String, Object?>{
          'names': <Object?>['probe'],
          'medians': <Object?>[0.0],
          'madScales': <Object?>[1.0],
          'missingDefaults': <Object?>[0.0],
          'distanceInner': 0.0,
          'distanceOuter': 4.0,
        };
        Map<String, Object?> blend(double treeBias) => <String, Object?>{
          'kind': DeviceDisplayModelCandidateEngine.constrainedBlend,
          'featureCenters': <Object?>[0.0],
          'featureScales': <Object?>[1.0],
          'weight': 0.5,
          'gam': <String, Object?>{
            'kind': DeviceDisplayModelCandidateEngine.naturalSplineGam,
            'intercept': 2.0,
            'coefficients': <Object?>[0.0],
            'knots': <Object?>[<Object?>[]],
          },
          'trees': <String, Object?>{
            'kind': DeviceDisplayModelCandidateEngine.shallowBoostedTrees,
            'bias': treeBias,
            'learningRate': 0.1,
            'trees': <Object?>[],
          },
        };
        Map<String, Object?> challenger(double intercept) => <String, Object?>{
          'kind': 'linear',
          'intercept': intercept,
          'coefficients': <Object?>[-0.2],
          'featureSchema': schema,
        };
        Map<String, Object?> prior(double intercept) => <String, Object?>{
          'kind': 'median',
          'intercept': intercept,
        };
        Map<String, Object?> gate({
          required double priorProbability,
          required double threshold,
        }) => <String, Object?>{
          'kind': 'quadratic_logistic',
          'fitted': true,
          'priorProbability': priorProbability,
          'threshold': threshold,
          'intercept': 2.1972245773362196,
          'coefficients': <Object?>[0.0, 0.0],
          'featureSchema': schema,
        };
        final disagreement = <String, Object?>{
          'available': true,
          'logicalPixelP50': 2.0,
          'logicalPixelP95': 18.0,
        };
        final iosSelected = blend(0.6);
        final iosChallenger = challenger(0.8);
        final iosPrior = prior(0.2);
        final iosGate = gate(priorProbability: 0.4, threshold: 0.3);
        final androidTopSelected = blend(0.4);
        final androidTopChallenger = challenger(0.7);
        final androidTopPrior = prior(0.1);
        final androidTopGate = gate(
          priorProbability: 0.4,
          threshold: 0.3,
        );
        final androidBottomSelected = blend(0);
        final androidBottomChallenger = challenger(0.5);
        final androidBottomPrior = prior(0.3);
        final androidBottomGate = gate(
          priorProbability: 0.1,
          threshold: 0.3,
        );
        final manifest = <String, Object?>{
          'safeInsetBaseline': <String, Object?>{'multiplier': 0.9},
          'platforms': <String, Object?>{
            'ios': <String, Object?>{
              'selectedCandidate': 'fixed_ios_pipeline',
              'predictionPipeline': 'distance_disagreement_gate_prior_v1',
              'headModels': <String, Object?>{'common': iosSelected},
              'challengerHeadModels': <String, Object?>{
                'common': iosChallenger,
              },
              'prior': <String, Object?>{
                'headModels': <String, Object?>{'common': iosPrior},
              },
              'classification': <String, Object?>{
                'commonGate': iosGate,
              },
              'disagreement': disagreement,
              'featureSchema': schema,
              'support': <String, Object?>{
                'modelBlendWeight': 0.5,
                'distanceTransitionScale': 0.5,
                'disagreementTransitionScale': 0.5,
              },
            },
            'android': <String, Object?>{
              'selectedCandidate': 'fixed_android_pipeline',
              'predictionPipeline': 'distance_disagreement_gate_prior_v1',
              'headModels': <String, Object?>{
                'top': androidTopSelected,
                'bottom': androidBottomSelected,
              },
              'challengerHeadModels': <String, Object?>{
                'top': androidTopChallenger,
                'bottom': androidBottomChallenger,
              },
              'prior': <String, Object?>{
                'headModels': <String, Object?>{
                  'top': androidTopPrior,
                  'bottom': androidBottomPrior,
                },
              },
              'classification': <String, Object?>{
                'topGate': androidTopGate,
                'bottomGate': androidBottomGate,
              },
              'disagreement': disagreement,
              'featureSchema': schema,
              'support': <String, Object?>{
                'modelBlendWeight': 0.5,
                'distanceTransitionScale': 0.5,
                'disagreementTransitionScale': 0.5,
              },
            },
          },
        };
        final manifestFile = File(
          '${temporaryDirectory.path}/manifest.json',
        )..writeAsStringSync(jsonEncode(manifest));
        final artifact = File('${temporaryDirectory.path}/model.g.dart');
        final generateResult = await DeviceDisplayModelTestProcess.run(<String>[
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'generate',
          '--manifest',
          manifestFile.path,
          '--output',
          artifact.path,
        ]);
        final harness = File('${temporaryDirectory.path}/harness.dart');
        final standaloneSource = artifact.readAsStringSync().replaceFirst(
          "part of 'device_display_estimator.dart';",
          "import 'dart:convert';\nimport 'dart:io';\n"
              "import 'dart:math' as math;",
        );
        harness.writeAsStringSync('''
$standaloneSource

void main() {
  const shortestLogicalSide = 100.0;
  const safeInsetDiameter = 0.15;
  final result = <String, Object?>{};
  for (final probe in <double>[0, 1, 2]) {
    final features = <double>[probe];
    final iosSelected = _DeviceDisplayEstimatorModel.iosNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    final iosChallenger =
        _DeviceDisplayEstimatorModel.iosChallengerNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
    );
    final iosSupport = math.min(
      _DeviceDisplayEstimatorModel.iosSupportWeight(features),
      _DeviceDisplayEstimatorModel.disagreementWeight(
        selectedDiameter: iosSelected,
        challengerDiameter: iosChallenger,
        shortestLogicalSide: shortestLogicalSide,
        innerLogicalPixels:
            _DeviceDisplayEstimatorModel.iosDisagreementInnerLogicalPixels,
        outerLogicalPixels:
            _DeviceDisplayEstimatorModel.iosDisagreementOuterLogicalPixels,
      ),
    );
    result['iosSupport\$probe'] = iosSupport;
    result['ios\$probe'] =
        _DeviceDisplayEstimatorModel.iosPipelineNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
      shortestLogicalSide: shortestLogicalSide,
    );
    result['androidtop\$probe'] = _DeviceDisplayEstimatorModel
        .androidTopPipelineNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
      shortestLogicalSide: shortestLogicalSide,
    );
    result['androidbottom\$probe'] = _DeviceDisplayEstimatorModel
        .androidBottomPipelineNormalizedDiameter(
      features,
      safeInsetDiameter: safeInsetDiameter,
      shortestLogicalSide: shortestLogicalSide,
    );
  }
  stdout.write(jsonEncode(result));
}
''');
        final harnessResult = await DeviceDisplayModelTestProcess.run(<String>[
          'dart',
          'run',
          harness.path,
        ]);
        final actual = jsonDecode((harnessResult.stdout as String).trim()) as Map<String, Object?>;
        double offline(
          double probe, {
          required Map<String, Object?> selected,
          required Map<String, Object?> challenger,
          required Map<String, Object?> prior,
          required Map<String, Object?> gate,
        }) => DeviceDisplayModelPipeline.predict(
          selectedModel: selected,
          challengerModel: challenger,
          priorModel: prior,
          gate: gate,
          featureSchema: schema,
          disagreement: disagreement,
          features: <double>[probe],
          safeInsetDiameter: 0.15,
          logicalRadiusScale: 50,
          modelBlendWeight: 0.5,
          distanceTransitionScale: 0.5,
          disagreementTransitionScale: 0.5,
        );
        final expected = <String, double>{};
        for (final probe in <double>[0, 1, 2]) {
          expected['iosSupport$probe'] = switch (probe) {
            0 => 1,
            1 => 0.5,
            _ => 0,
          };
          expected['ios$probe'] = offline(
            probe,
            selected: iosSelected,
            challenger: iosChallenger,
            prior: iosPrior,
            gate: iosGate,
          );
          expected['androidtop$probe'] = offline(
            probe,
            selected: androidTopSelected,
            challenger: androidTopChallenger,
            prior: androidTopPrior,
            gate: androidTopGate,
          );
          expected['androidbottom$probe'] = offline(
            probe,
            selected: androidBottomSelected,
            challenger: androidBottomChallenger,
            prior: androidBottomPrior,
            gate: androidBottomGate,
          );
        }

        expect(
          <Object?>[
            generateResult.exitCode,
            harnessResult.exitCode,
            for (final entry in expected.entries) (actual[entry.key]! as num).toDouble(),
          ],
          <Object?>[
            0,
            0,
            for (final entry in expected.entries) closeTo(entry.value, 0.0000001),
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
