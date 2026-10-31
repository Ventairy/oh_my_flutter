import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  test('when a cause is supplied, it should retain diagnostic context', () {
    final cause = StateError('sensor disconnected');
    expect(
      DeviceAccelerometerException(DeviceAccelerometerExceptionReason.operationUnavailable, cause: cause).cause,
      same(cause),
    );
  });
  test('when formatted, it should include the actionable reason', () {
    expect(
      const DeviceAccelerometerException(DeviceAccelerometerExceptionReason.sensorUnavailable).toString(),
      'DeviceAccelerometerException(reason: sensorUnavailable)',
    );
  });
}
