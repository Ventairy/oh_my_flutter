import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'when observing physical hardware, it should deliver native samples at default and faster requested intervals',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Accelerometer integration test'))));
      final results = await tester.runAsync(() async {
        const accelerometer = DeviceAccelerometer();
        if (!await accelerometer.isAvailable) throw StateError('Run this test on accelerometer-equipped hardware.');
        final results = <Map<String, Object>>[];
        for (final interval in [const Duration(milliseconds: 200), const Duration(milliseconds: 20)]) {
          final samples = await accelerometer
              .watch(samplingInterval: interval)
              .take(interval.inMilliseconds == 200 ? 10 : 3000)
              .toList()
              .timeout(const Duration(seconds: 90));
          final gaps = <int>[];
          for (var index = 1; index < samples.length; index += 1) {
            gaps.add((samples[index].timestamp - samples[index - 1].timestamp).inMicroseconds);
          }
          gaps.sort();
          results.add({
            'requested_interval_us': interval.inMicroseconds,
            'samples': samples.length,
            'finite': samples.every((sample) => sample.x.isFinite && sample.y.isFinite && sample.z.isFinite),
            'strictly_monotonic': gaps.every((gap) => gap > 0),
            'mean_interval_us': gaps.reduce((left, right) => left + right) / gaps.length,
            'p95_interval_us': gaps[(gaps.length * 0.95).floor()],
            'last_magnitude_squared':
                samples.last.x * samples.last.x + samples.last.y * samples.last.y + samples.last.z * samples.last.z,
          });
        }
        debugPrint('DEVICE_ACCELEROMETER_VALIDATION ${jsonEncode(results)}');
        return results;
      });
      expect(results, everyElement(containsPair('strictly_monotonic', true)));
    },
  );
}
