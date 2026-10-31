import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  final sample = DeviceAccelerometerSample(x: 1, y: 2, z: 3, timestamp: const Duration(seconds: 4));

  test('when samples match, it should use value equality', () {
    expect(sample, DeviceAccelerometerSample(x: 1, y: 2, z: 3, timestamp: const Duration(seconds: 4)));
  });
  test('when samples match, it should use matching hash codes', () {
    expect(
      sample.hashCode,
      DeviceAccelerometerSample(x: 1, y: 2, z: 3, timestamp: const Duration(seconds: 4)).hashCode,
    );
  });
  test('when timestamps differ, it should distinguish the samples', () {
    expect(sample, isNot(DeviceAccelerometerSample(x: 1, y: 2, z: 3, timestamp: const Duration(seconds: 5))));
  });
  for (final axis in ['x', 'y', 'z']) {
    for (final invalid in [double.nan, double.infinity, double.negativeInfinity]) {
      test('when $axis is $invalid, it should diagnose invalid configuration', () {
        expect(
          () => DeviceAccelerometerSample(
            x: axis == 'x' ? invalid : 0,
            y: axis == 'y' ? invalid : 0,
            z: axis == 'z' ? invalid : 0,
            timestamp: Duration.zero,
          ),
          throwsAssertionError,
        );
      });
    }
  }
  test('when the timestamp is negative, it should diagnose invalid configuration', () {
    expect(
      () => DeviceAccelerometerSample(x: 0, y: 0, z: 0, timestamp: const Duration(microseconds: -1)),
      throwsAssertionError,
    );
  });
}
