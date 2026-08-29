part of 'device_location_test.dart';

class _FakeDeviceLocationPlatform extends DeviceLocationPlatform {
  bool serviceEnabled = true;
  DeviceLocationPermissionStatus checkedPermission = DeviceLocationPermissionStatus.whileInUse;
  DeviceLocationPermissionStatus requestedPermission = DeviceLocationPermissionStatus.whileInUse;
  bool settingsOpened = true;
  Exception? serviceError;
  Exception? checkPermissionError;
  Exception? permissionRequestError;
  Exception? coordinatesError;
  Error? coordinatesErrorObject;
  Exception? addressError;
  Error? addressErrorObject;
  Exception? settingsError;
  int serviceChecks = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int coordinatesRequests = 0;
  int addressRequests = 0;
  int settingsRequests = 0;
  void Function()? onServiceEnabled;
  Completer<DeviceLocationPermissionStatus>? permissionCompleter;
  Completer<DeviceLocationCoordinates>? coordinatesCompleter;
  Completer<DeviceLocationAddress>? addressCompleter;
  String? localeIdentifier;

  DeviceLocationCoordinates coordinates = const DeviceLocationCoordinates(
    longitude: -46.844076,
    latitude: -23.556391,
    accuracy: 8.5,
  );
  DeviceLocationAddress address = const DeviceLocationAddress(
    coordinates: DeviceLocationCoordinates(
      longitude: -46.844076,
      latitude: -23.556391,
      accuracy: 8.5,
    ),
    formattedAddress: 'Rua Harmonia, 797\nSão Paulo - SP',
    street: 'Rua Harmonia',
    streetNumber: '797',
    neighborhood: 'Vila Madalena',
    district: 'São Paulo',
    city: 'São Paulo',
    state: 'SP',
    postalCode: '05435-001',
    country: 'Brasil',
    countryCode: 'BR',
  );

  @override
  Future<bool> isServiceEnabled() async {
    serviceChecks += 1;
    onServiceEnabled?.call();
    if (serviceError case final error?) throw error;
    return serviceEnabled;
  }

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() async {
    permissionChecks += 1;
    if (checkPermissionError case final error?) throw error;
    return checkedPermission;
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() async {
    permissionRequests += 1;
    if (permissionRequestError case final error?) throw error;
    if (permissionCompleter case final completer?) return completer.future;
    return requestedPermission;
  }

  @override
  Future<DeviceLocationCoordinates> getCurrentCoordinates() async {
    coordinatesRequests += 1;
    if (coordinatesError case final error?) throw error;
    if (coordinatesErrorObject case final error?) throw error;
    if (coordinatesCompleter case final completer?) return completer.future;
    return coordinates;
  }

  @override
  Future<DeviceLocationAddress> getAddress({
    required DeviceLocationCoordinates coordinates,
    required String? localeIdentifier,
  }) async {
    addressRequests += 1;
    this.localeIdentifier = localeIdentifier;
    if (addressError case final error?) throw error;
    if (addressErrorObject case final error?) throw error;
    if (addressCompleter case final completer?) return completer.future;
    return address;
  }

  @override
  Future<bool> openLocationSettings() async {
    settingsRequests += 1;
    if (settingsError case final error?) throw error;
    return settingsOpened;
  }
}
