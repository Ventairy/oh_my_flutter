import 'device_accelerometer_sample.dart';
import 'device_accelerometer_unsupported.dart'
    if (dart.library.io) 'device_accelerometer_io.dart'
    as default_implementation;

/// Provides platform operations for accelerometer access.
abstract class DeviceAccelerometerPlatform {
  /// Creates a platform implementation.
  const new();

  /// The implementation used for accelerometer access, replaceable in tests.
  static DeviceAccelerometerPlatform instance = default_implementation.DeviceAccelerometerPlatformImplementation();

  /// Whether an accelerometer is available without starting sampling.
  Future<bool> get isAvailable;

  /// Watches acceleration at the requested best-effort interval.
  Stream<DeviceAccelerometerSample> watch({required Duration samplingInterval});
}
