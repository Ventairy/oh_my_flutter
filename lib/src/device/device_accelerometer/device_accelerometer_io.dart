import 'dart:io';

import 'device_accelerometer_platform.dart';
import 'device_accelerometer_sample.dart';
import 'device_accelerometer_unsupported.dart' as unsupported;
import 'pigeon_device_accelerometer.dart';

/// Selects accelerometer access for the current operating system.
final class DeviceAccelerometerPlatformImplementation extends DeviceAccelerometerPlatform {
  /// Creates the implementation for this process.
  new()
    : _platform = (Platform.isAndroid || Platform.isIOS)
          ? PigeonDeviceAccelerometerPlatform()
          : unsupported.DeviceAccelerometerPlatformImplementation();

  final DeviceAccelerometerPlatform _platform;

  @override
  Future<bool> get isAvailable => _platform.isAvailable;

  @override
  Stream<DeviceAccelerometerSample> watch({required Duration samplingInterval}) =>
      _platform.watch(samplingInterval: samplingInterval);
}
