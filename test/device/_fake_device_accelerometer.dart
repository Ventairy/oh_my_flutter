part of 'device_test.dart';

final class _FakeDeviceAccelerometer implements DeviceAccelerometer {
  const new();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Stream<DeviceAccelerometerSample> watch({Duration samplingInterval = const Duration(milliseconds: 200)}) =>
      const Stream.empty();
}
