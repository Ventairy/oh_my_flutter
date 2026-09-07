import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'when generating windows bindings, it should reproduce the checked-in native interface',
    () async {
      final directory = Directory.systemTemp.createTempSync('country-bindings-test-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final output = File('${directory.path}/country_names_windows.g.dart');
      final result = await Process.run('fvm', [
        'dart',
        'run',
        'bin/generate_windows.dart',
        output.path,
      ]);
      if (!output.existsSync()) {
        fail('Generation did not produce output: ${result.stdout}\n${result.stderr}');
      }
      await Process.run('fvm', [
        'dart',
        'format',
        '--page-width',
        '120',
        '--trailing-commas',
        'preserve',
        output.path,
      ]);
      expect(
        (result.exitCode, output.readAsStringSync()),
        (0, File('../../lib/src/gen/country_names_windows.g.dart').readAsStringSync()),
        reason: '${result.stdout}\n${result.stderr}',
      );
    },
    skip: false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
