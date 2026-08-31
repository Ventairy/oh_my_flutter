import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('device display model validator', () {
    test('when evidence is sparse, it should report executed models without an accuracy claim', () async {
      final temporaryDirectory = Directory.systemTemp.createTempSync(
        'omf-display-validator-test-',
      );
      addTearDown(() => temporaryDirectory.deleteSync(recursive: true));
      final manifest = '${temporaryDirectory.path}/manifest.json';
      final report = File('${temporaryDirectory.path}/report.md');
      const executable = 'tool/device_display_model/device_display_model.dart';
      const corpus = 'test/tool/device_display_model/fixtures/corpus.json';

      await Process.run('fvm', [
        'dart',
        'run',
        executable,
        'train',
        '--corpus',
        corpus,
        '--output',
        manifest,
      ]);
      final result = await Process.run('fvm', [
        'dart',
        'run',
        executable,
        'validate',
        '--corpus',
        corpus,
        '--manifest',
        manifest,
        '--output',
        report.path,
      ]);
      final contents = report.readAsStringSync();

      expect(
        <Object?>[
          result.exitCode,
          contents.contains(
            '`spline_gam` | structured candidate | true | '
            '`fold_local_distance_disagreement_gate_prior_v1` | executed',
          ),
          contents.contains('best measured sparse-corpus fallback'),
          contents.contains('no calibrated accuracy claim'),
          contents.contains('Logical-pixel p95 absolute error'),
          contents.contains('hidden physical display unique IDs'),
        ],
        <Object?>[0, true, true, true, true, true],
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
