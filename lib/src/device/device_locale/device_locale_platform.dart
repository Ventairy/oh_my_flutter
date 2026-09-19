import 'device_locale_unsupported.dart' if (dart.library.io) 'device_locale_io.dart' as default_implementation;

/// Provides platform operations for locale access.
abstract class DeviceLocalePlatform {
  /// Creates a locale platform implementation.
  const new();

  /// The implementation used by locale requests, replaceable in tests.
  static DeviceLocalePlatform instance = default_implementation.DeviceLocalePlatformImplementation();

  /// Returns the configured region identifier when available.
  Future<String?> getCountry();
}
