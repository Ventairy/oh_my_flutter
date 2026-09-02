import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'device_display_model_test_process.dart';

void main() {
  group('device display model formulas', () {
    test(
      'when logical and proportional baselines compete, it should preserve their distinct formula kinds',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-model-formula-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final logicalManifest = await _train(
          temporaryDirectory,
          name: 'logical',
          radius: ({required shortSide, required density}) => 20 * density,
        );
        final proportionalManifest = await _train(
          temporaryDirectory,
          name: 'proportional',
          radius: ({required shortSide, required density}) => 0.08 * shortSide,
        );
        final logical = _android(logicalManifest);
        final proportional = _android(proportionalManifest);
        Map<String, Object?> comparator(
          Map<String, Object?> platform,
          String candidate,
        ) =>
            (platform['candidateScores']! as List<Object?>).cast<Map<String, Object?>>().singleWhere(
                  (score) => score['candidate'] == candidate,
                )['standaloneComparator']!
                as Map<String, Object?>;
        final logicalComparator = comparator(
          logical,
          'platform_median_logical_radius',
        );
        final proportionalComparator = comparator(
          proportional,
          'shortest_side_formula',
        );
        final logicalKinds = logicalComparator['headKinds']! as Map<String, Object?>;
        final proportionalKinds = proportionalComparator['headKinds']! as Map<String, Object?>;

        expect(
          <Object?>[
            logicalComparator['scoringPipeline'],
            logicalKinds['top'],
            logicalKinds['bottom'],
            proportionalComparator['scoringPipeline'],
            proportionalKinds['top'],
            proportionalKinds['bottom'],
          ],
          <Object?>[
            'standalone_raw_formula_grouped_oof_v1',
            'logical_radius_median',
            'logical_radius_median',
            'standalone_raw_formula_grouped_oof_v1',
            'shortest_side',
            'shortest_side',
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'when iOS major-axis padding order changes, it should encode the same natural feature pair',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-ios-feature-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final records = <Object?>[
          <String, Object?>{
            'platform': 'ios',
            'sourceKind': 'test_exact',
            'physicalWidth': 400.0,
            'physicalHeight': 800.0,
            'viewPhysicalWidth': 400.0,
            'viewPhysicalHeight': 800.0,
            'devicePixelRatio': 2.0,
            'viewPaddingLeftPhysical': 0.0,
            'viewPaddingTopPhysical': 20.0,
            'viewPaddingRightPhysical': 0.0,
            'viewPaddingBottomPhysical': 100.0,
            'topRadiusPhysical': 90.0,
            'bottomRadiusPhysical': 90.0,
            'cornerClassification': 'rounded',
            'familyGroupHash': 'portrait-family',
            'validationGroup': 'portrait-observation',
          },
          <String, Object?>{
            'platform': 'ios',
            'sourceKind': 'test_exact',
            'physicalWidth': 800.0,
            'physicalHeight': 400.0,
            'viewPhysicalWidth': 800.0,
            'viewPhysicalHeight': 400.0,
            'devicePixelRatio': 2.0,
            'viewPaddingLeftPhysical': 20.0,
            'viewPaddingTopPhysical': 0.0,
            'viewPaddingRightPhysical': 100.0,
            'viewPaddingBottomPhysical': 0.0,
            'topRadiusPhysical': 90.0,
            'bottomRadiusPhysical': 90.0,
            'cornerClassification': 'rounded',
            'familyGroupHash': 'landscape-family',
            'validationGroup': 'landscape-observation',
          },
        ];
        final corpus = File('${temporaryDirectory.path}/corpus.json')
          ..writeAsStringSync(jsonEncode(<String, Object?>{'records': records}));
        final manifest = File('${temporaryDirectory.path}/manifest.json');
        final result = await DeviceDisplayModelTestProcess.run(<String>[
          'dart',
          'run',
          'tool/device_display_model/device_display_model.dart',
          'train',
          '--corpus',
          corpus.path,
          '--output',
          manifest.path,
        ]);
        final ios =
            ((jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>)['platforms']!
                    as Map<String, Object?>)['ios']!
                as Map<String, Object?>;
        final medians = (ios['featureSchema']! as Map<String, Object?>)['medians']! as List<Object?>;
        final prior = ios['prior']! as Map<String, Object?>;
        final safeInsetScore = (ios['candidateScores']! as List<Object?>).cast<Map<String, Object?>>().singleWhere(
          (score) => score['candidate'] == 'safe_inset_baseline',
        );
        final standalone = safeInsetScore['standaloneComparator']! as Map<String, Object?>;
        final standaloneMetrics = standalone['metrics']! as Map<String, Object?>;

        expect(
          <Object?>[
            result.exitCode,
            medians[6],
            medians[7],
            prior['candidate'],
            standaloneMetrics['logicalPixelMae'],
          ],
          <Object?>[
            0,
            closeTo(0.5, 0.0000001),
            closeTo(0.1, 0.0000001),
            'safe_inset_baseline',
            closeTo(45, 0.0000001),
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

Future<Map<String, Object?>> _train(
  Directory directory, {
  required String name,
  required double Function({required double shortSide, required double density}) radius,
}) async {
  const shortSides = <double>[800, 1000, 1200, 1400];
  const densities = <double>[2, 2, 3, 2.5];
  final records = <Object?>[
    for (var index = 0; index < shortSides.length; index += 1)
      <String, Object?>{
        'platform': 'android',
        'sourceKind': 'test_exact',
        'physicalWidth': shortSides[index],
        'physicalHeight': 2 * shortSides[index],
        'viewPhysicalWidth': shortSides[index],
        'viewPhysicalHeight': 2 * shortSides[index],
        'devicePixelRatio': densities[index],
        'viewPaddingLeftPhysical': 0.0,
        'viewPaddingTopPhysical': 0.0,
        'viewPaddingRightPhysical': 0.0,
        'viewPaddingBottomPhysical': 0.0,
        'topRadiusPhysical': radius(
          shortSide: shortSides[index],
          density: densities[index],
        ),
        'bottomRadiusPhysical': radius(
          shortSide: shortSides[index],
          density: densities[index],
        ),
        'cornerClassification': 'rounded',
        'familyGroupHash': 'family-$index',
        'generationGroupHash': 'generation-$index',
        'oemGroupHash': 'oem',
        'observableCollisionGroupHash': 'observable-$index',
        'chronologyRank': index,
      },
  ];
  final corpus = File('${directory.path}/$name-corpus.json')
    ..writeAsStringSync(jsonEncode(<String, Object?>{'records': records}));
  final manifest = File('${directory.path}/$name-manifest.json');
  final result = await DeviceDisplayModelTestProcess.run(<String>[
    'dart',
    'run',
    'tool/device_display_model/device_display_model.dart',
    'train',
    '--corpus',
    corpus.path,
    '--output',
    manifest.path,
  ]);
  if (result.exitCode != 0) {
    throw StateError(result.stderr as String);
  }
  return jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
}

Map<String, Object?> _android(Map<String, Object?> manifest) =>
    (manifest['platforms']! as Map<String, Object?>)['android']! as Map<String, Object?>;
