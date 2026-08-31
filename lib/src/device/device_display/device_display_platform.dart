import 'device_display_platform_corner_radii.dart';
import 'device_display_unsupported.dart' if (dart.library.io) 'device_display_io.dart' as default_implementation;

/// Provides the platform operations used to inspect a device display.
///
/// Applications use `DeviceDisplay` rather than this platform boundary.
abstract class DeviceDisplayPlatform {
  /// Creates a device-display platform implementation.
  const DeviceDisplayPlatform();

  /// The platform implementation used for device-display requests.
  ///
  /// Platform registration and tests can replace this value. Applications
  /// should use `DeviceDisplay` instead.
  static DeviceDisplayPlatform instance = default_implementation.DeviceDisplayPlatformImplementation();

  /// Returns current-orientation display corner radii in physical pixels.
  ///
  /// A null value means the platform could not provide trustworthy radii.
  Future<DeviceDisplayPlatformCornerRadii?> getCornerRadii({
    required double displayWidth,
    required double displayHeight,
    required double viewWidth,
    required double viewHeight,
    required bool hasSinglePlatformView,
  });
}
