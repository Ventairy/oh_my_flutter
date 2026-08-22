library;

import 'dart:async';
import 'dart:ffi';

import 'package:meta/meta.dart';

import '../../../exceptions/device_location_exception.dart';
import '../../../exceptions/device_location_exception_reason.dart';
import '../device_location_coordinates.dart';
import '../device_location_permission_status.dart';
import '../device_location_platform.dart';

part 'apple_device_location_native_types.dart';

/// Retrieves foreground device location through iOS Core Location.
final class AppleDeviceLocationPlatform extends DeviceLocationPlatform {
  /// Creates the Core Location implementation.
  AppleDeviceLocationPlatform()
    : this._(
        isServiceEnabled: () => _requestValue(_nativeIsServiceEnabled),
        checkPermission: () => _requestValue(_nativeCheckPermission),
        requestPermission: () => _requestValue(_nativeRequestPermission),
        getCurrentCoordinates: _requestCoordinatesValue,
        openLocationSettings: () => _requestValue(_nativeOpenSettings),
      );

  /// Creates an implementation with replaceable operations for tests.
  @visibleForTesting
  const AppleDeviceLocationPlatform.test({
    required Future<({int value, int failure})> Function() isServiceEnabled,
    required Future<({int value, int failure})> Function() checkPermission,
    required Future<({int value, int failure})> Function() requestPermission,
    required Future<
      ({
        double latitude,
        double longitude,
        double accuracy,
        int failure,
      })
    >
    Function()
    getCurrentCoordinates,
    required Future<({int value, int failure})> Function() openLocationSettings,
  }) : this._(
         isServiceEnabled: isServiceEnabled,
         checkPermission: checkPermission,
         requestPermission: requestPermission,
         getCurrentCoordinates: getCurrentCoordinates,
         openLocationSettings: openLocationSettings,
       );

  const AppleDeviceLocationPlatform._({
    required Future<({int value, int failure})> Function() isServiceEnabled,
    required Future<({int value, int failure})> Function() checkPermission,
    required Future<({int value, int failure})> Function() requestPermission,
    required Future<
      ({
        double latitude,
        double longitude,
        double accuracy,
        int failure,
      })
    >
    Function()
    getCurrentCoordinates,
    required Future<({int value, int failure})> Function() openLocationSettings,
  }) : _isServiceEnabledOperation = isServiceEnabled,
       _checkPermissionOperation = checkPermission,
       _requestPermissionOperation = requestPermission,
       _getCurrentCoordinatesOperation = getCurrentCoordinates,
       _openLocationSettingsOperation = openLocationSettings;

  final Future<_AppleValueResult> Function() _isServiceEnabledOperation;
  final Future<_AppleValueResult> Function() _checkPermissionOperation;
  final Future<_AppleValueResult> Function() _requestPermissionOperation;
  final Future<_AppleCoordinatesResult> Function() _getCurrentCoordinatesOperation;
  final Future<_AppleValueResult> Function() _openLocationSettingsOperation;

  @override
  Future<bool> isServiceEnabled() async {
    final result = await _isServiceEnabledOperation();
    _throwIfFailed(result.failure);
    return switch (result.value) {
      0 => false,
      1 => true,
      _ => throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      ),
    };
  }

  @override
  Future<DeviceLocationPermissionStatus> checkPermission() async {
    final result = await _checkPermissionOperation();
    _throwIfFailed(result.failure);
    return _permissionFor(result.value);
  }

  @override
  Future<DeviceLocationPermissionStatus> requestPermission() async {
    final result = await _requestPermissionOperation();
    _throwIfFailed(result.failure);
    return _permissionFor(result.value);
  }

  @override
  Future<DeviceLocationCoordinates> getCurrentCoordinates() async {
    final result = await _getCurrentCoordinatesOperation();
    _throwIfFailed(result.failure);
    final latitude = result.latitude;
    final longitude = result.longitude;
    final accuracy = result.accuracy;
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !accuracy.isFinite ||
        accuracy < 0) {
      throw const DeviceLocationException(
        DeviceLocationExceptionReason.coordinatesUnavailable,
      );
    }

    return DeviceLocationCoordinates(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
  }

  @override
  Future<bool> openLocationSettings() async {
    final result = await _openLocationSettingsOperation();
    _throwIfFailed(result.failure);
    return switch (result.value) {
      0 => false,
      1 => true,
      _ => throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      ),
    };
  }

  static Future<_AppleCoordinatesResult> _requestCoordinatesValue() {
    final completer = Completer<_AppleCoordinatesResult>();
    late final NativeCallable<_AppleCoordinatesCallbackNative> callback;
    callback = NativeCallable<_AppleCoordinatesCallbackNative>.listener(
      (double latitude, double longitude, double accuracy, int failure) {
        callback.close();
        completer.complete(
          (
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            failure: failure,
          ),
        );
      },
    );
    try {
      _nativeRequestCoordinates(callback.nativeFunction);
    } on Object {
      callback.close();
      rethrow;
    }
    return completer.future;
  }

  static Future<_AppleValueResult> _requestValue(
    void Function(Pointer<NativeFunction<_AppleValueCallbackNative>>) request,
  ) {
    final completer = Completer<_AppleValueResult>();
    late final NativeCallable<_AppleValueCallbackNative> callback;
    callback = NativeCallable<_AppleValueCallbackNative>.listener((
      int value,
      int failure,
    ) {
      callback.close();
      completer.complete((value: value, failure: failure));
    });
    try {
      request(callback.nativeFunction);
    } on Object {
      callback.close();
      rethrow;
    }
    return completer.future;
  }

  static DeviceLocationPermissionStatus _permissionFor(int value) {
    return switch (value) {
      0 => DeviceLocationPermissionStatus.notDetermined,
      1 => DeviceLocationPermissionStatus.deniedForever,
      2 => DeviceLocationPermissionStatus.restricted,
      3 => DeviceLocationPermissionStatus.whileInUse,
      4 => DeviceLocationPermissionStatus.always,
      _ => throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      ),
    };
  }

  static void _throwIfFailed(int failure) {
    if (failure != 0) throw _exceptionFor(failure);
  }

  static DeviceLocationException _exceptionFor(int failure) {
    final reason = switch (failure) {
      1 => DeviceLocationExceptionReason.servicesDisabled,
      2 => DeviceLocationExceptionReason.permissionDenied,
      3 => DeviceLocationExceptionReason.permissionPermanentlyDenied,
      4 => DeviceLocationExceptionReason.configurationMissing,
      5 => DeviceLocationExceptionReason.operationUnavailable,
      _ => DeviceLocationExceptionReason.coordinatesUnavailable,
    };
    return DeviceLocationException(reason);
  }

  @RecordUse()
  @Native<Void Function(Pointer<NativeFunction<_AppleValueCallbackNative>>)>(
    symbol: 'omf_device_location_is_service_enabled',
  )
  external static void _nativeIsServiceEnabled(
    Pointer<NativeFunction<_AppleValueCallbackNative>> callback,
  );

  @RecordUse()
  @Native<Void Function(Pointer<NativeFunction<_AppleValueCallbackNative>>)>(
    symbol: 'omf_device_location_check_permission',
  )
  external static void _nativeCheckPermission(
    Pointer<NativeFunction<_AppleValueCallbackNative>> callback,
  );

  @RecordUse()
  @Native<Void Function(Pointer<NativeFunction<_AppleValueCallbackNative>>)>(
    symbol: 'omf_device_location_request_permission',
  )
  external static void _nativeRequestPermission(
    Pointer<NativeFunction<_AppleValueCallbackNative>> callback,
  );

  @RecordUse()
  @Native<Void Function(Pointer<NativeFunction<_AppleCoordinatesCallbackNative>>)>(
    symbol: 'omf_device_location_request_coordinates',
  )
  external static void _nativeRequestCoordinates(
    Pointer<NativeFunction<_AppleCoordinatesCallbackNative>> callback,
  );

  @RecordUse()
  @Native<Void Function(Pointer<NativeFunction<_AppleValueCallbackNative>>)>(
    symbol: 'omf_device_location_open_settings',
  )
  external static void _nativeOpenSettings(
    Pointer<NativeFunction<_AppleValueCallbackNative>> callback,
  );
}
