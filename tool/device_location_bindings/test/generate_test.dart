import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'when generating device location bindings, it should reproduce the checked-in native interface',
    () async {
      final directory = Directory.systemTemp.createTempSync('device-location-bindings-test-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final output = File('${directory.path}/apple_device_location_native_bindings.g.dart');
      final result = await Process.run('fvm', [
        'dart',
        'run',
        'bin/generate.dart',
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
        (
          0,
          File(
            '../../lib/src/device/device_location/apple_device_location/'
            'apple_device_location_native_bindings.g.dart',
          ).readAsStringSync(),
        ),
        reason: '${result.stdout}\n${result.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
