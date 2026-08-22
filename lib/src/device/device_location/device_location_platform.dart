import 'device_location_coordinates.dart';
import 'device_location_permission_status.dart';
import 'device_location_unsupported.dart' if (dart.library.io) 'device_location_io.dart' as default_implementation;

/// Provides the platform operations used by `DeviceLocation`.
///
/// Applications use `DeviceLocation` rather than this platform boundary.
abstract class DeviceLocationPlatform {
  /// Creates a device-location platform implementation.
  const DeviceLocationPlatform();

  /// The platform implementation used for device-location requests.
  ///
  /// Platform registration and tests can replace this value. Applications
  /// should use `DeviceLocation` instead.
  static DeviceLocationPlatform instance = default_implementation.DeviceLocationPlatformImplementation();

  /// Reports whether the system location service is available and enabled.
  Future<bool> isServiceEnabled();

  /// Reports the current foreground location permission.
  Future<DeviceLocationPermissionStatus> checkPermission();

  /// Requests foreground location permission.
  Future<DeviceLocationPermissionStatus> requestPermission();

  /// Retrieves current coordinates at the best available accuracy.
  Future<DeviceLocationCoordinates> getCurrentCoordinates();

  /// Opens the deepest supported settings page for the app's location access.
  Future<bool> openLocationSettings();
}
