import 'dart:io';

import 'device_sim_platform.dart';
import 'device_sim_unsupported.dart' as unsupported;
import 'pigeon_device_sim.dart';

/// Selects the SIM implementation for the current operating system.
final class DeviceSimPlatformImplementation extends DeviceSimPlatform {
  /// Creates the implementation for this process.
  new() : _platform = Platform.isAndroid ? PigeonDeviceSimPlatform() : unsupported.DeviceSimPlatformImplementation();

  final DeviceSimPlatform _platform;

  @override
  Future<String?> getCountry() => _platform.getCountry();
}
