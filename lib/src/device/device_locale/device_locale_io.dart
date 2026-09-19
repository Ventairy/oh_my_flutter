import 'dart:io';

import 'device_locale_platform.dart';
import 'device_locale_unsupported.dart' as unsupported;
import 'pigeon_device_locale.dart';

/// Selects the locale implementation for the current operating system.
final class DeviceLocalePlatformImplementation extends DeviceLocalePlatform {
  /// Creates the implementation for this process.
  new()
    : _platform = (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows)
          ? PigeonDeviceLocalePlatform()
          : unsupported.DeviceLocalePlatformImplementation();

  final DeviceLocalePlatform _platform;

  @override
  Future<String?> getCountry() => _platform.getCountry();
}
