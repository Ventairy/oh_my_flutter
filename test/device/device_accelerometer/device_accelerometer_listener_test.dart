import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_accelerometer/pigeon_device_accelerometer.dart';
import 'package:oh_my_flutter/src/gen/device_accelerometer/device_accelerometer.g.dart';

part '_mock_device_accelerometer_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'when a long measurement gap occurs, it should deliver one real reading without synthesizing missed samples',
    () async {
      final host = _MockDeviceAccelerometerHost();
      when(() => host.configure(any())).thenAnswer((_) async {});
      final source = StreamController<DeviceAccelerometerPlatformSample>.broadcast();
      final platform = PigeonDeviceAccelerometerPlatform.test(api: host, samples: () => source.stream);
      final samples = <DeviceAccelerometerSample>[];
      final subscription = platform.watch(samplingInterval: const Duration(milliseconds: 200)).listen(samples.add);
      await Future<void>.delayed(Duration.zero);
      source
        ..add(DeviceAccelerometerPlatformSample(x: 0, y: 0, z: 0, timestampMicroseconds: 0))
        ..add(DeviceAccelerometerPlatformSample(x: 0, y: 0, z: 0, timestampMicroseconds: 10000000));
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await source.close();
      expect(samples.map((sample) => sample.timestamp), [Duration.zero, const Duration(seconds: 10)]);
    },
  );
}
