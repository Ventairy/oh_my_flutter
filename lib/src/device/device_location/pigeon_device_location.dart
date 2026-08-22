import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../exceptions/device_location_exception.dart';
import '../../exceptions/device_location_exception_reason.dart';
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
    }
  }

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() async {
    try {
      return _mapPermission(await _api.checkPermission());
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() async {
    try {
      return _mapPermission(await _api.requestPermission());
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<DeviceLocationCoordinates> getCurrentCoordinates() async {
    try {
      final coordinates = await _api.getCurrentCoordinates();
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
    } on PlatformException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await _api.openLocationSettings();
    } on PlatformException catch (error) {
      throw _mapError(error);
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
}
