import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_accelerometer/device_accelerometer_platform.dart';

void main() {
  test('when selecting a default platform, it should provide an implementation', () {
    expect(DeviceAccelerometerPlatform.instance, isA<DeviceAccelerometerPlatform>());
  });
}
