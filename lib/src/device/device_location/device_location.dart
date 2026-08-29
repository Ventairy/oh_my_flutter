import 'package:flutter/widgets.dart' show Locale;

import '../../exceptions/device_location_exception.dart';
import '../../exceptions/device_location_exception_reason.dart';
import 'device_location_address.dart';
import 'device_location_coordinates.dart';
import 'device_location_permission_status.dart';
import 'device_location_platform.dart';

/// Manages foreground location permission and retrieves device location data.
///
/// ```dart
/// final coordinates = await const DeviceLocation().getCurrentCoordinates();
/// print('${coordinates.latitude}, ${coordinates.longitude}');
/// final address = await const DeviceLocation().getCurrentAddress();
/// print(address.street ?? address.formattedAddress);
/// ```
///
/// Handle [DeviceLocationException] when a requested operation is unavailable.
/// Other platforms complete with [DeviceLocationExceptionReason.unsupportedPlatform].
///
/// See the [device location guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/device_location.md)
/// for platform setup and failure handling.
interface class DeviceLocation {
  /// Creates a utility for managing the device's foreground location access.
  const DeviceLocation();

  static DeviceLocationPlatform? _permissionPlatform;
  static Future<DeviceLocationPermissionStatus>? _pendingPermission;
  static DeviceLocationPlatform? _coordinatesPlatform;
  static Future<DeviceLocationCoordinates>? _pendingCoordinates;
  static final List<
    ({
      DeviceLocationPlatform platform,
      DeviceLocationCoordinates coordinates,
      String? localeIdentifier,
      Future<DeviceLocationAddress> future,
    })
  >
  _pendingAddresses = [];

  /// Reports the application's current foreground location permission.
  ///
  /// This getter never displays a permission prompt. Android reports
  /// [DeviceLocationPermissionStatus.denied] whenever permission is ungranted because
  /// a status check cannot reliably distinguish an initial state from a
  /// permanent denial.
  ///
  /// Throws [DeviceLocationException] when host configuration is missing or
  /// the operation is unavailable on the current platform.
  Future<DeviceLocationPermissionStatus> get permissionStatus {
    return _checkPermission(DeviceLocationPlatform.instance);
  }

  /// Requests foreground location permission and returns the resulting status.
  ///
  /// Already-granted, permanently denied, or restricted permission completes
  /// with its current status without displaying another system prompt.
  /// Overlapping calls share one native permission request.
  ///
  /// This method does not require system location services to be enabled.
  /// Throws [DeviceLocationException] when host configuration is missing or
  /// the operation cannot be completed.
  Future<DeviceLocationPermissionStatus> requestPermission() {
    return _requestPermission(DeviceLocationPlatform.instance);
  }

  /// Retrieves fresh foreground coordinates at the best available accuracy.
  ///
  /// When [requestPermission] is true and permission is missing, the operating
  /// system may display its permission prompt. When it is false, this method
  /// never prompts and throws [DeviceLocationException] for missing permission.
  /// Reduced or approximate accuracy selected by the user remains valid.
  ///
  /// Overlapping acquisitions share one native coordinates request. A call
  /// made after that request completes starts a fresh request.
  Future<DeviceLocationCoordinates> getCurrentCoordinates({
    bool requestPermission = true,
  }) {
    final platform = DeviceLocationPlatform.instance;
    return _getCurrentCoordinatesWithPlatform(
      platform,
      requestPermission: requestPermission,
    );
  }

  /// Retrieves the device-formatted address for fresh foreground coordinates.
  ///
  /// Select a component such as [DeviceLocationAddress.street], or use
  /// [DeviceLocationAddress.formattedAddress] when the device provides a
  /// display-ready address. Components are nullable because device geocoders
  /// can return partial results.
  ///
  /// When [requestPermission] is true and permission is missing, the operating
  /// system may display its permission prompt. When it is false, this method
  /// never prompts and reports the same permission failures as
  /// [getCurrentCoordinates]. [locale] is a best-effort preference; when it is
  /// null, the device locale is used.
  ///
  /// After fresh coordinates are available, reverse geocoding has a 30-second
  /// deadline. Exceeding it reports
  /// [DeviceLocationExceptionReason.operationUnavailable].
  ///
  /// Overlapping calls for the same coordinate acquisition and locale share
  /// one reverse-geocoding request. Later calls acquire fresh coordinates and
  /// do not use a completed address as a cache.
  ///
  /// Throws [DeviceLocationException] with
  /// [DeviceLocationExceptionReason.operationUnavailable] when the device
  /// cannot provide a usable address.
  Future<DeviceLocationAddress> getCurrentAddress({
    bool requestPermission = true,
    Locale? locale,
  }) async {
    try {
      final platform = DeviceLocationPlatform.instance;
      final coordinates = await _getCurrentCoordinatesWithPlatform(
        platform,
        requestPermission: requestPermission,
      );
      return await _getAddress(
        platform,
        coordinates,
        locale?.toLanguageTag(),
      );
    } on DeviceLocationException {
      rethrow;
    } on Object catch (error) {
      throw DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
        cause: error,
      );
    }
  }

  Future<DeviceLocationCoordinates> _getCurrentCoordinatesWithPlatform(
    DeviceLocationPlatform platform, {
    required bool requestPermission,
  }) async {
    try {
      await _ensureLocationServicesEnabled(platform);
      var permission = await _checkPermission(platform);

      if (!permission.isGranted && requestPermission) {
        permission = await _requestPermission(platform);
      }

      _ensurePermissionGranted(permission);
      return await _getCurrentCoordinates(platform);
    } on DeviceLocationException {
      rethrow;
    } on Exception catch (error) {
      throw DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
        cause: error,
      );
    }
  }

  Future<DeviceLocationAddress> _getAddress(
    DeviceLocationPlatform platform,
    DeviceLocationCoordinates coordinates,
    String? localeIdentifier,
  ) {
    for (final pending in _pendingAddresses) {
      if (identical(pending.platform, platform) &&
          identical(pending.coordinates, coordinates) &&
          pending.localeIdentifier == localeIdentifier) {
        return pending.future;
      }
    }

    late final Future<DeviceLocationAddress> request;

    request = _performAddressRequest(platform, coordinates, localeIdentifier).whenComplete(() {
      _pendingAddresses.removeWhere(
        (pending) => identical(pending.future, request),
      );
    });
    _pendingAddresses.add((
      platform: platform,
      coordinates: coordinates,
      localeIdentifier: localeIdentifier,
      future: request,
    ));
    return request;
  }

  Future<DeviceLocationAddress> _performAddressRequest(
    DeviceLocationPlatform platform,
    DeviceLocationCoordinates coordinates,
    String? localeIdentifier,
  ) async {
    try {
      return await platform.getAddress(
        coordinates: coordinates,
        localeIdentifier: localeIdentifier,
      );
    } on DeviceLocationException {
      rethrow;
    } on Object catch (error) {
      throw DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
        cause: error,
      );
    }
  }

  /// Opens the deepest supported system settings page for location access.
  ///
  /// Android and iOS open the application's settings page, where users can
  /// change its location permission. Returns whether the operating system
  /// accepted the navigation request. This method never requests permission.
  Future<bool> openLocationSettings() async {
    try {
      return await DeviceLocationPlatform.instance.openLocationSettings();
    } on DeviceLocationException {
      rethrow;
    } on Exception catch (error) {
      throw DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
        cause: error,
      );
    }
  }

  Future<DeviceLocationPermissionStatus> _checkPermission(
    DeviceLocationPlatform platform,
  ) async {
    try {
      return await platform.checkPermission();
    } on DeviceLocationException {
      rethrow;
    } on Exception catch (error) {
      throw DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
        cause: error,
      );
    }
  }

  Future<DeviceLocationPermissionStatus> _requestPermission(
    DeviceLocationPlatform platform,
  ) {
    final pending = _pendingPermission;
    if (pending != null && identical(_permissionPlatform, platform)) {
      return pending;
    }

    late final Future<DeviceLocationPermissionStatus> request;
    request = _performPermissionRequest(platform).whenComplete(() {
      if (identical(_pendingPermission, request)) {
        _pendingPermission = null;
        _permissionPlatform = null;
      }
    });
    _permissionPlatform = platform;
    _pendingPermission = request;
    return request;
  }

  Future<DeviceLocationPermissionStatus> _performPermissionRequest(
    DeviceLocationPlatform platform,
  ) async {
    try {
      final permission = await platform.checkPermission();
      if (permission.isGranted ||
          permission == DeviceLocationPermissionStatus.deniedForever ||
          permission == DeviceLocationPermissionStatus.restricted) {
        return permission;
      }
      return await platform.requestPermission();
    } on DeviceLocationException {
      rethrow;
    } on Exception catch (error) {
      throw DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
        cause: error,
      );
    }
  }

  Future<DeviceLocationCoordinates> _getCurrentCoordinates(
    DeviceLocationPlatform platform,
  ) {
    final pending = _pendingCoordinates;
    if (pending != null && identical(_coordinatesPlatform, platform)) {
      return pending;
    }

    late final Future<DeviceLocationCoordinates> request;
    request = _performCoordinatesRequest(platform).whenComplete(() {
      if (identical(_pendingCoordinates, request)) {
        _pendingCoordinates = null;
        _coordinatesPlatform = null;
      }
    });
    _coordinatesPlatform = platform;
    _pendingCoordinates = request;
    return request;
  }

  Future<DeviceLocationCoordinates> _performCoordinatesRequest(
    DeviceLocationPlatform platform,
  ) async {
    try {
      return await platform.getCurrentCoordinates();
    } on DeviceLocationException {
      rethrow;
    } on Exception catch (error) {
      throw DeviceLocationException(
        DeviceLocationExceptionReason.coordinatesUnavailable,
        cause: error,
      );
    }
  }

  Future<void> _ensureLocationServicesEnabled(
    DeviceLocationPlatform platform,
  ) async {
    final enabled = await platform.isServiceEnabled();
    if (enabled) return;

    throw const DeviceLocationException(
      DeviceLocationExceptionReason.servicesDisabled,
    );
  }

  void _ensurePermissionGranted(DeviceLocationPermissionStatus permission) {
    switch (permission) {
      case DeviceLocationPermissionStatus.notDetermined:
      case DeviceLocationPermissionStatus.denied:
        throw const DeviceLocationException(
          DeviceLocationExceptionReason.permissionDenied,
        );
      case DeviceLocationPermissionStatus.deniedForever:
      case DeviceLocationPermissionStatus.restricted:
        throw const DeviceLocationException(
          DeviceLocationExceptionReason.permissionPermanentlyDenied,
        );
      case DeviceLocationPermissionStatus.whileInUse:
      case DeviceLocationPermissionStatus.always:
        return;
    }
  }
}
