import 'dart:async';

import '../../exceptions/device_accelerometer_exception.dart';
import '../../exceptions/device_accelerometer_exception_reason.dart';
import 'device_accelerometer_platform.dart';
import 'device_accelerometer_sample.dart';

/// Reports unavailable accelerometer access on unsupported platforms.
final class DeviceAccelerometerPlatformImplementation extends DeviceAccelerometerPlatform {
  /// Creates an unsupported implementation.
  new();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Stream<DeviceAccelerometerSample> watch({required Duration samplingInterval}) =>
      Stream<DeviceAccelerometerSample>.multi((controller) {
        controller.addError(const DeviceAccelerometerException(DeviceAccelerometerExceptionReason.unsupportedPlatform));
        unawaited(controller.close());
      }, isBroadcast: true);
}
