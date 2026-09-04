import 'dart:io';

import 'device_display_platform.dart';
import 'device_display_platform_corner_radii.dart';
import 'device_display_unsupported.dart' as unsupported;
import 'pigeon_device_display.dart';

/// Selects the mobile device-display implementation for this process.
final class DeviceDisplayPlatformImplementation extends DeviceDisplayPlatform {
  /// Creates the implementation for the current operating system.
  DeviceDisplayPlatformImplementation() : _platform = _createPlatform();

  final DeviceDisplayPlatform _platform;

  static DeviceDisplayPlatform _createPlatform() {
    if (Platform.isAndroid || Platform.isIOS) {
      return PigeonDeviceDisplayPlatform();
    }
    return unsupported.DeviceDisplayPlatformImplementation();
  }

  @override
  Future<DeviceDisplayPlatformCornerRadii?> getCornerRadii({
    required double displayWidth,
    required double displayHeight,
    required double viewWidth,
    required double viewHeight,
    required bool hasSinglePlatformView,
  }) {
    return _platform.getCornerRadii(
      displayWidth: displayWidth,
      displayHeight: displayHeight,
      viewWidth: viewWidth,
      viewHeight: viewHeight,
      hasSinglePlatformView: hasSinglePlatformView,
    );
  }
}
