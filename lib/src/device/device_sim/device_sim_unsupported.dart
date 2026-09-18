import 'device_sim_platform.dart';

/// Provides unavailable results on platforms without SIM country access.
final class DeviceSimPlatformImplementation extends DeviceSimPlatform {
  /// Creates an unsupported SIM implementation.
  DeviceSimPlatformImplementation();

  @override
  Future<String?> getCountry() async => null;
}
