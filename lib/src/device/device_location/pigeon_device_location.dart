import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../exceptions/device_location_exception.dart';
import '../../exceptions/device_location_exception_reason.dart';
import 'device_location_address.dart';
import 'device_location_coordinates.dart';
import 'device_location_permission_status.dart';
import 'device_location_platform.dart';
import 'pigeon/android_device_location.g.dart';

/// Retrieves Android location information through the generated host API.
final class PigeonDeviceLocationPlatform extends DeviceLocationPlatform {
  /// Creates the Android device-location platform implementation.
  PigeonDeviceLocationPlatform() : _api = AndroidDeviceLocationApi();

  /// Creates an implementation backed by a test host API.
  @visibleForTesting
  PigeonDeviceLocationPlatform.test(this._api);

  final AndroidDeviceLocationApi _api;

  @override
  Future<bool> isServiceEnabled() async {
    try {
      return await _api.isServiceEnabled();
    } on PlatformException catch (error) {
      throw _mapError(error);
    } on Object catch (error) {
      throw _unexpectedPlatformError(error);
    }
  }

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() async {
    final AndroidDeviceLocationPermissionStatus permission;
    try {
      permission = await _api.checkPermission();
    } on PlatformException catch (error) {
      throw _mapError(error);
    } on Object catch (error) {
      throw _unexpectedPlatformError(error);
    }
    return _mapPermission(permission);
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() async {
    final AndroidDeviceLocationPermissionStatus permission;
    try {
      permission = await _api.requestPermission();
    } on PlatformException catch (error) {
      throw _mapError(error);
    } on Object catch (error) {
      throw _unexpectedPlatformError(error);
    }
    return _mapPermission(permission);
  }

  @override
  Future<DeviceLocationCoordinates> getCurrentCoordinates() async {
    final AndroidDeviceCoordinates coordinates;
    try {
      coordinates = await _api.getCurrentCoordinates();
    } on PlatformException catch (error) {
      throw _mapError(error);
    } on Object catch (error) {
      throw _unexpectedPlatformError(error);
    }
    if (!_areValidCoordinates(coordinates)) {
      throw const DeviceLocationException(
        DeviceLocationExceptionReason.coordinatesUnavailable,
      );
    }
    return DeviceLocationCoordinates(
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      accuracy: coordinates.accuracy,
    );
  }

  @override
  Future<DeviceLocationAddress> getAddress({
    required DeviceLocationCoordinates coordinates,
    required String? localeIdentifier,
  }) async {
    final AndroidDeviceLocationAddress address;
    try {
      address = await _api.getAddress(
        coordinates.latitude,
        coordinates.longitude,
        localeIdentifier,
        _addressTimeoutMilliseconds,
      );
    } on PlatformException catch (error) {
      throw _mapError(error);
    } on Object catch (error) {
      throw _unexpectedPlatformError(error);
    }
    final formattedAddress = _normalized(address.formattedAddress);
    final name = _normalized(address.name);
    final street = _normalized(address.street);
    final streetNumber = _normalized(address.streetNumber);
    final neighborhood = _normalized(address.neighborhood);
    final district = _normalized(address.district);
    final city = _normalized(address.city);
    final state = _normalized(address.state);
    final postalCode = _normalized(address.postalCode);
    final country = _normalized(address.country);
    final countryCode = _countryCode(address.countryCode);
    if (formattedAddress == null &&
        name == null &&
        street == null &&
        streetNumber == null &&
        neighborhood == null &&
        district == null &&
        city == null &&
        state == null &&
        postalCode == null &&
        country == null &&
        countryCode == null) {
      throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      );
    }

    return DeviceLocationAddress(
      coordinates: coordinates,
      formattedAddress: formattedAddress,
      name: name,
      street: street,
      streetNumber: streetNumber,
      neighborhood: neighborhood,
      district: district,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      countryCode: countryCode,
    );
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await _api.openLocationSettings();
    } on PlatformException catch (error) {
      throw _mapError(error);
    } on Object catch (error) {
      throw _unexpectedPlatformError(error);
    }
  }

  DeviceLocationPermissionStatus _mapPermission(
    AndroidDeviceLocationPermissionStatus permission,
  ) {
    return switch (permission) {
      AndroidDeviceLocationPermissionStatus.denied => DeviceLocationPermissionStatus.denied,
      AndroidDeviceLocationPermissionStatus.deniedForever => DeviceLocationPermissionStatus.deniedForever,
      AndroidDeviceLocationPermissionStatus.whileInUse => DeviceLocationPermissionStatus.whileInUse,
    };
  }

  bool _areValidCoordinates(AndroidDeviceCoordinates coordinates) {
    return coordinates.latitude.isFinite &&
        coordinates.latitude >= -90 &&
        coordinates.latitude <= 90 &&
        coordinates.longitude.isFinite &&
        coordinates.longitude >= -180 &&
        coordinates.longitude <= 180 &&
        coordinates.accuracy.isFinite &&
        coordinates.accuracy >= 0;
  }

  String? _normalized(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? _countryCode(String? value) {
    final normalized = _normalized(value);
    if (normalized == null) return null;
    if (!_isAsciiCountryCode(normalized)) return null;
    return normalized.toUpperCase();
  }

  bool _isAsciiCountryCode(String value) {
    if (value.length != 2) return false;
    return value.codeUnits.every(
      (codeUnit) => (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122),
    );
  }

  DeviceLocationException _unexpectedPlatformError(Object error) {
    return DeviceLocationException(
      DeviceLocationExceptionReason.operationUnavailable,
      cause: error,
    );
  }

  DeviceLocationException _mapError(PlatformException error) {
    final reason = switch (error.details) {
      AndroidDeviceLocationFailure.servicesDisabled => DeviceLocationExceptionReason.servicesDisabled,
      AndroidDeviceLocationFailure.permissionDenied => DeviceLocationExceptionReason.permissionDenied,
      AndroidDeviceLocationFailure.permissionPermanentlyDenied =>
        DeviceLocationExceptionReason.permissionPermanentlyDenied,
      AndroidDeviceLocationFailure.configurationMissing => DeviceLocationExceptionReason.configurationMissing,
      AndroidDeviceLocationFailure.operationUnavailable => DeviceLocationExceptionReason.operationUnavailable,
      AndroidDeviceLocationFailure.coordinatesUnavailable => DeviceLocationExceptionReason.coordinatesUnavailable,
      _ => _failureForCode(error.code),
    };
    return DeviceLocationException(reason, cause: error);
  }

  DeviceLocationExceptionReason _failureForCode(String code) {
    return switch (code) {
      'servicesDisabled' => DeviceLocationExceptionReason.servicesDisabled,
      'permissionDenied' => DeviceLocationExceptionReason.permissionDenied,
      'permissionPermanentlyDenied' => DeviceLocationExceptionReason.permissionPermanentlyDenied,
      'configurationMissing' => DeviceLocationExceptionReason.configurationMissing,
      'coordinatesUnavailable' => DeviceLocationExceptionReason.coordinatesUnavailable,
      _ => DeviceLocationExceptionReason.operationUnavailable,
    };
  }

  static const _addressTimeoutMilliseconds = 30_000;
}
