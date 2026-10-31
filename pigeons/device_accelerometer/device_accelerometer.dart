import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/gen/device_accelerometer/device_accelerometer.g.dart',
    kotlinOut: 'lib/src/gen/device_accelerometer/android/DeviceAccelerometer.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.ventairy.oh_my_flutter.device_accelerometer'),
    swiftOut: 'lib/src/gen/device_accelerometer/apple/DeviceAccelerometer.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'DeviceAccelerometerPigeonError'),
    dartPackageName: 'oh_my_flutter',
  ),
)
class DeviceAccelerometerPlatformSample {
  new({
    required this.x,
    required this.y,
    required this.z,
    required this.timestampMicroseconds,
  });

  double x;
  double y;
  double z;
  int timestampMicroseconds;
}

@HostApi()
abstract class DeviceAccelerometerHostApi {
  bool isAvailable();

  /// A null interval stops sampling; a positive interval configures it.
  void configure(int? samplingIntervalMicroseconds);
}

@EventChannelApi()
abstract class DeviceAccelerometerEventApi {
  DeviceAccelerometerPlatformSample deviceAccelerometerSamples();
}
