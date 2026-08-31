import 'device_display_platform.dart';
import 'device_display_platform_corner_radii.dart';

/// Reports unavailable display geometry on unsupported platforms.
final class DeviceDisplayPlatformImplementation extends DeviceDisplayPlatform {
  /// Creates an unsupported device-display implementation.
  DeviceDisplayPlatformImplementation();

  @override
  Future<DeviceDisplayPlatformCornerRadii?> getCornerRadii({
    required double displayWidth,
    required double displayHeight,
    required double viewWidth,
    required double viewHeight,
    required bool hasSinglePlatformView,
  }) async => null;
}
