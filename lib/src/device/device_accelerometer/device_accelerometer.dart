import '../../exceptions/device_accelerometer_exception.dart';
import 'device_accelerometer_platform.dart';
import 'device_accelerometer_sample.dart';

/// Helps applications respond to acceleration measured by the device.
///
/// Use directly or through `Device().accelerometer`. Supports Android and iOS.
/// See the [accelerometer guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/device_accelerometer.md)
/// for axes, sampling, failure handling, and subscription ownership.
interface class DeviceAccelerometer {
  /// Creates a utility for accessing the device's accelerometer.
  const new();

  /// Whether this platform and device provide an accelerometer.
  ///
  /// Does not start sampling or display a permission prompt. Returns false on
  /// unsupported platforms or when hardware is absent. Access failures throw a
  /// [DeviceAccelerometerException]. Availability does not guarantee that a
  /// later subscription will succeed.
  Future<bool> get isAvailable => DeviceAccelerometerPlatform.instance.isAvailable;

  /// Watches acceleration including gravity, in meters per second squared.
  ///
  /// Listening starts updates; calling this method alone does not. The returned
  /// broadcast stream supports multiple listeners and does not replay old data.
  /// [samplingInterval] requests the time between readings and must be positive.
  /// The default is 200 milliseconds. Actual timing depends on the device; use
  /// each sample's timestamp when elapsed time matters.
  ///
  /// Updates suspend while the app is not resumed and continue with fresh data
  /// on return. Cancel subscriptions when their screen no longer needs updates;
  /// cancellation releases access when no listeners remain. Await cancellation
  /// to wait for cleanup. Standard subscription pause behavior buffers readings:
  /// cancel and subscribe again to avoid accumulating unwanted history.
  ///
  /// Failures, including unsupported platforms, emit a
  /// [DeviceAccelerometerException] and close the affected subscriptions. Listen
  /// again to retry. No automatic permission prompt or retry is performed.
  Stream<DeviceAccelerometerSample> watch({Duration samplingInterval = const Duration(milliseconds: 200)}) {
    assert(samplingInterval > Duration.zero, 'samplingInterval must be positive');
    return DeviceAccelerometerPlatform.instance.watch(samplingInterval: samplingInterval);
  }
}
