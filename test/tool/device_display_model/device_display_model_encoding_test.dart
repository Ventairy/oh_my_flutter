import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/device_display_model/device_display_model.dart';

void main() {
  group('device display model encoding', () {
    test(
      'when the shared iOS group seed is hashed, it should match the collector SHA prefix',
      () {
        expect(
          DeviceDisplayModelEncoding.groupFingerprint('oem:apple'),
          'sha256:e003f62c8ae9c62a',
        );
      },
    );

    test(
      'when map insertion order changes, it should preserve the manifest bytes',
      () async {
        final temporaryDirectory = Directory.systemTemp.createTempSync(
          'omf-display-encoding-test-',
        );
        addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
        final original = jsonDecode(
          File(
            'test/tool/device_display_model/fixtures/corpus.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final reordered = _reverseMaps(original)! as Map<String, Object?>;
        final reorderedCorpus = File(
          '${temporaryDirectory.path}/reordered-corpus.json',
        )..writeAsStringSync(jsonEncode(reordered));
        final originalManifest = File(
          '${temporaryDirectory.path}/original-manifest.json',
        );
        final reorderedManifest = File(
          '${temporaryDirectory.path}/reordered-manifest.json',
        );

        final results = await Future.wait(<Future<ProcessResult>>[
          _train(
            corpus: 'test/tool/device_display_model/fixtures/corpus.json',
            manifest: originalManifest.path,
          ),
          _train(
            corpus: reorderedCorpus.path,
            manifest: reorderedManifest.path,
          ),
        ]);

        expect(
          <Object?>[
            for (final result in results) result.exitCode,
            (jsonDecode(originalManifest.readAsStringSync()) as Map<String, Object?>)['corpusFingerprint'],
            reorderedManifest.readAsStringSync(),
          ],
          <Object?>[
            0,
            0,
            matches(RegExp(r'^fnv1a64:[0-9a-f]{16}$')),
            originalManifest.readAsStringSync(),
          ],
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

Future<ProcessResult> _train({
  required String corpus,
  required String manifest,
}) => Process.run('fvm', <String>[
  'dart',
  'run',
  'tool/device_display_model/device_display_model.dart',
  'train',
  '--corpus',
  corpus,
  '--output',
  manifest,
]);

Object? _reverseMaps(Object? value) {
  if (value is Map<String, Object?>) {
    return <String, Object?>{
      for (final key in value.keys.toList().reversed) key: _reverseMaps(value[key]),
    };
  }
  if (value is List<Object?>) {
    return <Object?>[for (final item in value) _reverseMaps(item)];
  }
  return value;
}
