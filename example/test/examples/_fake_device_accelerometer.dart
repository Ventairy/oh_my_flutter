part of 'device_accelerometer_example_test.dart';

final class _FakeDeviceAccelerometer implements DeviceAccelerometer {
  new(this.source);

  final StreamController<DeviceAccelerometerSample> source;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Stream<DeviceAccelerometerSample> watch({Duration samplingInterval = const Duration(milliseconds: 200)}) =>
      source.stream;
}
