import 'dart:io';

import 'apple_device_location/apple_device_location_platform.dart';
import 'device_location_coordinates.dart';
import 'device_location_permission_status.dart';
import 'device_location_platform.dart';
import 'device_location_unsupported.dart' as unsupported;
import 'pigeon_device_location.dart';

/// Selects the Android or iOS device-location implementation for this process.
final class DeviceLocationPlatformImplementation extends DeviceLocationPlatform {
  /// Creates the implementation for the current operating system.
  DeviceLocationPlatformImplementation() : _platform = _createPlatform();

  final DeviceLocationPlatform _platform;

  static DeviceLocationPlatform _createPlatform() {
    if (Platform.isAndroid) return PigeonDeviceLocationPlatform();

    if (Platform.isIOS) return AppleDeviceLocationPlatform();
    return unsupported.DeviceLocationPlatformImplementation();
  }

  @override
  Future<bool> isServiceEnabled() => _platform.isServiceEnabled();

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() {
    return _platform.checkPermission();
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() {
    return _platform.requestPermission();
  }

  @override
  Future<DeviceLocationCoordinates> getCurrentCoordinates() {
    return _platform.getCurrentCoordinates();
  }

  @override
  Future<bool> openLocationSettings() => _platform.openLocationSettings();
}
