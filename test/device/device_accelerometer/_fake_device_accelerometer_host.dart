part of 'device_accelerometer_coordinator_test.dart';

final class _FakeDeviceAccelerometerHost extends DeviceAccelerometerHostApi {
  final configurations = <int?>[];
  Future<void> Function(int?)? onConfigure;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> configure(int? samplingIntervalMicroseconds) async {
    configurations.add(samplingIntervalMicroseconds);
    await onConfigure?.call(samplingIntervalMicroseconds);
  }
}
