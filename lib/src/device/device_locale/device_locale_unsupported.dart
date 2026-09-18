import 'device_locale_platform.dart';

/// Provides unavailable results on platforms without locale country access.
final class DeviceLocalePlatformImplementation extends DeviceLocalePlatform {
  /// Creates an unsupported locale implementation.
  DeviceLocalePlatformImplementation();

  @override
  Future<String?> getCountry() async => null;
}
