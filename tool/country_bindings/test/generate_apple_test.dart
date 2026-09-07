import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'when generating apple bindings, it should reproduce the checked-in native interface',
    () async {
      final directory = Directory.systemTemp.createTempSync('country-bindings-test-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final output = File('${directory.path}/country_names_apple.g.dart');
      final result = await Process.run('fvm', [
        'dart',
        'run',
        'bin/generate_apple.dart',
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
        (0, File('../../lib/src/gen/country_names_apple.g.dart').readAsStringSync()),
        reason: '${result.stdout}\n${result.stderr}',
      );
    },
    skip: !Platform.isMacOS,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
