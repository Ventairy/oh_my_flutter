import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/device_display_model/device_display_model.dart';

void main() {
  group('device display model generator', () {
    test('when the same manifest is generated twice, it should be byte deterministic', () async {
      final temporaryDirectory = Directory.systemTemp.createTempSync(
        'omf-display-generator-test-',
      );
      addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
      final manifest = '${temporaryDirectory.path}/manifest.json';
      final firstArtifact = File('${temporaryDirectory.path}/first.g.dart');
      final secondArtifact = File('${temporaryDirectory.path}/second.g.dart');
      const executable = 'tool/device_display_model/device_display_model.dart';

      await Process.run('fvm', [
        'dart',
        'run',
        executable,
        'train',
        '--corpus',
        'test/tool/device_display_model/fixtures/corpus.json',
        '--output',
        manifest,
      ]);
      final firstResult = await Process.run('fvm', [
        'dart',
        'run',
        executable,
        'generate',
        '--manifest',
        manifest,
        '--output',
        firstArtifact.path,
      ]);
      final secondResult = await Process.run('fvm', [
        'dart',
        'run',
        executable,
        'generate',
        '--manifest',
        manifest,
        '--output',
        secondArtifact.path,
      ]);

      expect(
        <Object?>[
          firstResult.exitCode,
          secondResult.exitCode,
          firstArtifact.readAsStringSync(),
        ],
        <Object?>[
          0,
          0,
          secondArtifact.readAsStringSync(),
        ],
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'when candidate models are emitted, it should match every training predictor and reject unknown kinds',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-generator-equivalence-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final manifest = '${temporaryDirectory.path}/manifest.json';
        final artifact = File('${temporaryDirectory.path}/model.g.dart');
        const executable = 'tool/device_display_model/device_display_model.dart';
        await Process.run('fvm', [
          'dart',
          'run',
          executable,
          'train',
          '--corpus',
          'test/tool/device_display_model/fixtures/corpus.json',
          '--output',
          manifest,
        ]);
        await Process.run('fvm', [
          'dart',
          'run',
          executable,
          'generate',
          '--manifest',
          manifest,
          '--output',
          artifact.path,
        ]);
        final trainingFeatures = <List<double>>[
          for (var index = 0; index < 12; index += 1)
            <double>[
              index / 11,
              ((index * 5) % 12) / 11,
              ((index * 7) % 12) / 11,
            ],
        ];
        final targets = <double>[
          for (var index = 0; index < trainingFeatures.length; index += 1)
            0.08 + 0.2 * trainingFeatures[index][0] + (index.isEven ? 0.04 : 0),
        ];
        final models = <Map<String, Object?>>[
          <String, Object?>{
            'kind': 'shortest_side',
            'normalizedDiameter': 0.23,
          },
          <String, Object?>{
            'kind': 'logical_radius_median',
            'logicalRadius': 0.1,
          },
          for (final candidate in const <String>[
            DeviceDisplayModelCandidateEngine.robustQuadratic,
            DeviceDisplayModelCandidateEngine.naturalSplineGam,
            DeviceDisplayModelCandidateEngine.shallowBoostedTrees,
            DeviceDisplayModelCandidateEngine.constrainedBlend,
          ])
            DeviceDisplayModelCandidateEngine.fit(
              candidate: candidate,
              features: trainingFeatures,
              targets: targets,
            ),
          <String, Object?>{
            'kind': DeviceDisplayModelCandidateEngine.constrainedBlend,
            'featureCenters': <double>[0, 0, 0],
            'featureScales': <double>[1, 1, 1],
            'weight': 0.5,
            'gam': <String, Object?>{
              'kind': DeviceDisplayModelCandidateEngine.naturalSplineGam,
              'intercept': 2.0,
              'coefficients': <double>[0, 0, 0],
              'knots': <List<double>>[<double>[], <double>[], <double>[]],
            },
            'trees': <String, Object?>{
              'kind': DeviceDisplayModelCandidateEngine.shallowBoostedTrees,
              'bias': 0.5,
              'learningRate': 0.1,
              'trees': <List<double>>[],
            },
          },
        ];
        const probe = <double>[0.37, 0.58, 0.21];
        final expected = <double>[
          0.23,
          0.2 / math.exp(probe[2]),
          for (final model in models.skip(2))
            DeviceDisplayModelCandidateEngine.predict(
              model: model,
              features: probe,
            ),
        ];
        final harness = File('${temporaryDirectory.path}/harness.dart');
        final standaloneSource = artifact.readAsStringSync().replaceFirst(
          "part of 'device_display_estimator.dart';",
          "import 'dart:convert';\nimport 'dart:io';\n"
              "import 'dart:math' as math;",
        );
        harness.writeAsStringSync('''
$standaloneSource

void main(List<String> arguments) {
  final payload = jsonDecode(arguments.single) as Map<String, Object?>;
  final features = (payload['features']! as List<Object?>)
      .map((value) => (value! as num).toDouble())
      .toList();
  final models = (payload['models']! as List<Object?>)
      .map((value) => (value! as Map<String, Object?>))
      .toList();
  stdout.write(jsonEncode(<double>[
    for (final model in models)
      _DeviceDisplayEstimatorModel._predict(model, features, 0.1),
  ]));
}
''');
        final equivalentResult = await Process.run('fvm', [
          'dart',
          'run',
          harness.path,
          jsonEncode(<String, Object?>{
            'models': models,
            'features': probe,
          }),
        ]);
        final actual = (jsonDecode((equivalentResult.stdout as String).trim()) as List<Object?>)
            .map((value) => (value! as num).toDouble())
            .toList();
        final unknownResult = await Process.run('fvm', [
          'dart',
          'run',
          harness.path,
          jsonEncode(<String, Object?>{
            'models': <Object?>[
              <String, Object?>{
                'kind': 'unknown_rich_kind',
                'featureCenters': <double>[0, 0, 0],
                'featureScales': <double>[1, 1, 1],
              },
            ],
            'features': probe,
          }),
        ]);

        expect(
          <Object?>[
            equivalentResult.exitCode,
            ...actual,
            unknownResult.exitCode == 0,
            unknownResult.stderr as String,
          ],
          <Object?>[
            0,
            for (final value in expected) closeTo(value, 0.0000001),
            false,
            contains('Unknown generated display-radius model kind'),
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
