import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  test('when describing accelerometer failures, it should distinguish platform, hardware, permission, and operation failures', () {
    expect(DeviceAccelerometerExceptionReason.values.map((reason) => reason.name), [
      'unsupportedPlatform',
      'sensorUnavailable',
      'permissionDenied',
      'operationUnavailable',
    ]);
  });
}
