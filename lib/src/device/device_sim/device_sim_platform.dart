import 'device_sim_unsupported.dart' if (dart.library.io) 'device_sim_io.dart' as default_implementation;

/// Provides platform operations for SIM access.
abstract class DeviceSimPlatform {
  /// Creates a SIM platform implementation.
  const new();

  /// The implementation used by SIM requests, replaceable in tests.
  static DeviceSimPlatform instance = default_implementation.DeviceSimPlatformImplementation();

  /// Returns the SIM provider's ISO alpha-2 country code when available.
  Future<String?> getCountry();
}
