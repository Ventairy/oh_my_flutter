part of 'pigeon_device_accelerometer.dart';

final class _DeviceAccelerometerListener {
  new({required this.controller, required this.intervalMicroseconds});

  final MultiStreamController<DeviceAccelerometerSample> controller;
  final int intervalMicroseconds;
  int? nextTimestamp;

  void add(DeviceAccelerometerSample sample) {
    final timestamp = sample.timestamp.inMicroseconds;
    final next = nextTimestamp;
    if (next != null && timestamp < next) return;
    nextTimestamp = next == null
        ? timestamp + intervalMicroseconds
        : next + ((timestamp - next) ~/ intervalMicroseconds + 1) * intervalMicroseconds;
    controller.add(sample);
  }
}
