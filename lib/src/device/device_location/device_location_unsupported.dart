import '../../exceptions/device_location_exception.dart';
import '../../exceptions/device_location_exception_reason.dart';
import 'device_location_address.dart';
import 'device_location_coordinates.dart';
import 'device_location_permission_status.dart';
import 'device_location_platform.dart';

/// Reports that device location is unavailable on an unsupported platform.
final class DeviceLocationPlatformImplementation extends DeviceLocationPlatform {
  /// Creates an unsupported device-location implementation.
  DeviceLocationPlatformImplementation();

  static const _error = DeviceLocationException(
    DeviceLocationExceptionReason.unsupportedPlatform,
  );

  @override
  Future<bool> isServiceEnabled() => Future<bool>.error(_error);

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() {
    return Future<DeviceLocationPermissionStatus>.error(_error);
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() {
    return Future<DeviceLocationPermissionStatus>.error(_error);
  }

  @override
  Future<DeviceLocationCoordinates> getCurrentCoordinates() {
    return Future<DeviceLocationCoordinates>.error(_error);
  }

  @override
  Future<DeviceLocationAddress> getAddress({
    required DeviceLocationCoordinates coordinates,
    required String? localeIdentifier,
  }) {
    return Future<DeviceLocationAddress>.error(_error);
  }

  @override
  Future<bool> openLocationSettings() {
    return Future<bool>.error(_error);
  }
}
