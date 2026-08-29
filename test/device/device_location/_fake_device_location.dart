part of 'device_location_test.dart';

class _FakeDeviceLocation implements DeviceLocation {
  const _FakeDeviceLocation();

  @override
  Future<DeviceLocationPermissionStatus> get permissionStatus async {
    return DeviceLocationPermissionStatus.whileInUse;
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() async {
    return DeviceLocationPermissionStatus.whileInUse;
  }

  @override
  Future<DeviceLocationCoordinates> getCurrentCoordinates({
    bool requestPermission = true,
  }) async {
    return const DeviceLocationCoordinates(
      latitude: 0,
      longitude: 0,
      accuracy: 0,
    );
  }

  @override
  Future<DeviceLocationAddress> getCurrentAddress({
    bool requestPermission = true,
    Locale? locale,
  }) async {
    return const DeviceLocationAddress(
      coordinates: DeviceLocationCoordinates(
        latitude: 0,
        longitude: 0,
        accuracy: 0,
      ),
      countryCode: 'BR',
    );
  }

  @override
  Future<bool> openLocationSettings() async => true;
}
