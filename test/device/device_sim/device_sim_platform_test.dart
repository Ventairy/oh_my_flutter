import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_sim/device_sim_platform.dart';

void main() {
  test('when initialized on an unsupported host, it should return null', () {
    expect(DeviceSimPlatform.instance.getCountry(), completion(isNull));
  });
}
