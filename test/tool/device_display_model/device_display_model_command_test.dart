import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'device_display_model_test_process.dart';

void main() {
  group('device display model command', () {
    test('when generated files match their corpus, it should reject stale or catalog material', () async {
      final temporaryDirectory = Directory.systemTemp.createTempSync(
        'omf-display-command-test-',
      );
      addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
      final manifest = '${temporaryDirectory.path}/manifest.json';
      final artifact = '${temporaryDirectory.path}/model.g.dart';
      final report = '${temporaryDirectory.path}/report.md';
      const executable = 'tool/device_display_model/device_display_model.dart';
      const corpus = 'test/tool/device_display_model/fixtures/corpus.json';

      await DeviceDisplayModelTestProcess.run([
        'dart',
        'run',
        executable,
        'train',
        '--corpus',
        corpus,
        '--output',
        manifest,
      ]);
      await DeviceDisplayModelTestProcess.run([
        'dart',
        'run',
        executable,
        'generate',
        '--manifest',
        manifest,
        '--output',
        artifact,
      ]);
      await DeviceDisplayModelTestProcess.run([
        'dart',
        'run',
        executable,
        'validate',
        '--corpus',
        corpus,
        '--manifest',
        manifest,
        '--output',
        report,
      ]);
      final cleanResult = await DeviceDisplayModelTestProcess.run([
        'dart',
        'run',
        executable,
        'check',
        '--corpus',
        corpus,
        '--manifest',
        manifest,
        '--artifact',
        artifact,
        '--report',
        report,
      ]);
      File(artifact).writeAsStringSync(
        '// sourceObservationHash must never ship\n',
        mode: FileMode.append,
      );
      final forbiddenResult = await DeviceDisplayModelTestProcess.run([
        'dart',
        'run',
        executable,
        'check',
        '--corpus',
        corpus,
        '--manifest',
        manifest,
        '--artifact',
        artifact,
        '--report',
        report,
      ]);

      expect(
        <Object?>[
          cleanResult.exitCode,
          cleanResult.stdout as String,
          forbiddenResult.exitCode,
          forbiddenResult.stdout as String,
        ],
        <Object?>[
          0,
          contains('"artifactMatchesManifest": true'),
          1,
          contains('"shippingArtifactHasForbiddenCatalogMaterial": true'),
        ],
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('when shipping estimator source is scanned, it should exclude private and identity tokens', () {
      final contents = Directory(
        'lib/src/device/device_display/estimator',
      ).listSync(recursive: true).whereType<File>().map((file) => file.readAsStringSync()).join('\n');

      expect(
        RegExp(
          'NSSelectorFromString|_displayCornerRadius|sourceObservationHash|familyGroupHash|generationGroupHash|oemGroupHash|maskCollisionGroupHash|manufacturer|modelIdentifier|deviceIdentifier',
          caseSensitive: false,
        ).hasMatch(contents),
        isFalse,
      );
    });

    test(
      'when the publish listing is checked, it should reject excluded tooling and private source',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-archive-check-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final libDirectory = Directory('${temporaryDirectory.path}/lib')..createSync();
        File('${libDirectory.path}/safe.dart').writeAsStringSync(
          'final class SafeSource {}\n',
        );
        final listing = File('${temporaryDirectory.path}/listing.txt')
          ..writeAsStringSync('''
Publishing fixture 1.0.0 to https://pub.dev:
└── lib
    └── safe.dart (<1 KB)

Total compressed archive size: 1 KB.
''');
        const executable = 'tool/device_display_model/device_display_model.dart';
        final cleanResult = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          executable,
          'check-publish-archive',
          '--package-root',
          temporaryDirectory.path,
          '--listing',
          listing.path,
        ]);

        final excludedTestDirectory = Directory(
          '${temporaryDirectory.path}/test/tool/device_display_model',
        )..createSync(recursive: true);
        File('${excludedTestDirectory.path}/collector_test.dart').writeAsStringSync(
          'const marker = "collector";\n',
        );
        listing.writeAsStringSync('''
Publishing fixture 1.0.0 to https://pub.dev:
├── lib
│   └── safe.dart (<1 KB)
└── test
    └── tool
        └── device_display_model
            └── collector_test.dart (<1 KB)

Total compressed archive size: 1 KB.
''');
        final excludedResult = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          executable,
          'check-publish-archive',
          '--package-root',
          temporaryDirectory.path,
          '--listing',
          listing.path,
        ]);

        File('${libDirectory.path}/safe.dart').writeAsStringSync(
          'const selector = "NSSelectorFromString";\n',
        );
        listing.writeAsStringSync('''
Publishing fixture 1.0.0 to https://pub.dev:
└── lib
    └── safe.dart (<1 KB)

Total compressed archive size: 1 KB.
''');
        final privateResult = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          executable,
          'check-publish-archive',
          '--package-root',
          temporaryDirectory.path,
          '--listing',
          listing.path,
        ]);
        final assetDirectory = Directory(
          '${temporaryDirectory.path}/assets',
        )..createSync();
        File('${assetDirectory.path}/payload.bin').writeAsBytesSync(
          <int>[0, ...'containerConcentricRadius'.codeUnits, 0xff],
        );
        listing.writeAsStringSync('''
Publishing fixture 1.0.0 to https://pub.dev:
└── assets
    └── payload.bin (<1 KB)

Total compressed archive size: 1 KB.
''');
        final binaryResult = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          executable,
          'check-publish-archive',
          '--package-root',
          temporaryDirectory.path,
          '--listing',
          listing.path,
        ]);
        File('${assetDirectory.path}/payload.bin').writeAsBytesSync(
          <int>[0, ...'CornerRadiusCollectorActivity'.codeUnits, 0xff],
        );
        final relocatedAndroidResult = await DeviceDisplayModelTestProcess.run([
          'dart',
          'run',
          executable,
          'check-publish-archive',
          '--package-root',
          temporaryDirectory.path,
          '--listing',
          listing.path,
        ]);

        expect(
          <Object?>[
            cleanResult.exitCode,
            excludedResult.exitCode,
            excludedResult.stdout as String,
            privateResult.exitCode,
            privateResult.stdout as String,
            binaryResult.exitCode,
            binaryResult.stdout as String,
            relocatedAndroidResult.exitCode,
            relocatedAndroidResult.stdout as String,
          ],
          <Object?>[
            0,
            1,
            contains('"archiveIncludesExcludedMaintainerTooling": true'),
            1,
            contains('"shippingSourceHasPrivateCollectorMaterial": true'),
            1,
            contains('"shippingSourceHasPrivateCollectorMaterial": true'),
            1,
            contains('"shippingSourceHasPrivateCollectorMaterial": true'),
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
