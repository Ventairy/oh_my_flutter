import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_accelerometer/device_accelerometer_platform.dart';

part '_mock_device_accelerometer_platform.dart';

void main() {
  late DeviceAccelerometerPlatform previous;
  late DeviceAccelerometerPlatform platform;
  setUp(() {
    previous = DeviceAccelerometerPlatform.instance;
    platform = _MockDeviceAccelerometerPlatform();
    DeviceAccelerometerPlatform.instance = platform;
  });
  tearDown(() => DeviceAccelerometerPlatform.instance = previous);

  test('when availability is requested, it should delegate to the platform', () {
    when(() => platform.isAvailable).thenAnswer((_) async => true);
    expect(const DeviceAccelerometer().isAvailable, completion(isTrue));
  });
  test('when watch has no interval, it should request 200 milliseconds', () {
    const stream = Stream<DeviceAccelerometerSample>.empty();
    when(() => platform.watch(samplingInterval: const Duration(milliseconds: 200))).thenAnswer((_) => stream);
    expect(const DeviceAccelerometer().watch(), same(stream));
  });
  test('when watch has a custom interval, it should pass it unchanged', () {
    const stream = Stream<DeviceAccelerometerSample>.empty();
    when(() => platform.watch(samplingInterval: const Duration(milliseconds: 20))).thenAnswer((_) => stream);
    expect(const DeviceAccelerometer().watch(samplingInterval: const Duration(milliseconds: 20)), same(stream));
  });
  for (final interval in [Duration.zero, const Duration(microseconds: -1)]) {
    test('when the interval is $interval, it should diagnose invalid configuration', () {
      expect(() => const DeviceAccelerometer().watch(samplingInterval: interval), throwsAssertionError);
    });
  }
}
