library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:meta/meta.dart';

import '../../../exceptions/device_location_exception.dart';
import '../../../exceptions/device_location_exception_reason.dart';
import '../device_location_address.dart';
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
        getAddress: _requestAddressValue,
        openLocationSettings: () => _requestValue(_nativeOpenSettings),
      );

  /// Creates an implementation with replaceable operations for tests.
  @visibleForTesting
  factory AppleDeviceLocationPlatform.test({
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
    Future<({String? addressJson, int failure})> Function(
      double latitude,
      double longitude,
      String? localeIdentifier,
      int timeoutMilliseconds,
    )?
    getAddress,
    void Function(
      double latitude,
      double longitude,
      Pointer<Uint8> localeIdentifier,
      int timeoutMilliseconds,
      Pointer<NativeFunction<Void Function(Pointer<Uint8>, Int32)>> callback,
    )?
    requestAddress,
    Pointer<Void> Function(int size)? allocate,
    void Function(Pointer<Void> value)? free,
  }) {
    assert(
      getAddress != null || (requestAddress != null && allocate != null && free != null),
      'getAddress or every native address operation must be supplied',
    );
    assert(
      getAddress == null || (requestAddress == null && allocate == null && free == null),
      'high-level and native address operations cannot be mixed',
    );
    return AppleDeviceLocationPlatform._(
      isServiceEnabled: isServiceEnabled,
      checkPermission: checkPermission,
      requestPermission: requestPermission,
      getCurrentCoordinates: getCurrentCoordinates,
      getAddress:
          getAddress ??
          (latitude, longitude, localeIdentifier, timeoutMilliseconds) {
            return _requestAddressValueWithOperations(
              latitude,
              longitude,
              localeIdentifier,
              timeoutMilliseconds,
              requestAddress: requestAddress!,
              allocate: allocate!,
              free: free!,
            );
          },
      openLocationSettings: openLocationSettings,
    );
  }

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
    required Future<_AppleAddressResult> Function(
      double latitude,
      double longitude,
      String? localeIdentifier,
      int timeoutMilliseconds,
    )
    getAddress,
    required Future<({int value, int failure})> Function() openLocationSettings,
  }) : _isServiceEnabledOperation = isServiceEnabled,
       _checkPermissionOperation = checkPermission,
       _requestPermissionOperation = requestPermission,
       _getCurrentCoordinatesOperation = getCurrentCoordinates,
       _getAddressOperation = getAddress,
       _openLocationSettingsOperation = openLocationSettings;

  final Future<_AppleValueResult> Function() _isServiceEnabledOperation;
  final Future<_AppleValueResult> Function() _checkPermissionOperation;
  final Future<_AppleValueResult> Function() _requestPermissionOperation;
  final Future<_AppleCoordinatesResult> Function() _getCurrentCoordinatesOperation;
  final Future<_AppleAddressResult> Function(
    double latitude,
    double longitude,
    String? localeIdentifier,
    int timeoutMilliseconds,
  )
  _getAddressOperation;
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
  Future<DeviceLocationAddress> getAddress({
    required DeviceLocationCoordinates coordinates,
    required String? localeIdentifier,
  }) async {
    final result = await _getAddressOperation(
      coordinates.latitude,
      coordinates.longitude,
      localeIdentifier,
      _addressTimeoutMilliseconds,
    );
    _throwIfFailed(result.failure);
    final addressJson = result.addressJson;
    if (addressJson == null) {
      throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(addressJson);
    } on FormatException catch (error) {
      throw DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
        cause: error,
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      );
    }

    final formattedAddress = _addressValue(decoded, 'formattedAddress');
    final name = _addressValue(decoded, 'name');
    final street = _addressValue(decoded, 'street');
    final streetNumber = _addressValue(decoded, 'streetNumber');
    final neighborhood = _addressValue(decoded, 'neighborhood');
    final district = _addressValue(decoded, 'district');
    final city = _addressValue(decoded, 'city');
    final state = _addressValue(decoded, 'state');
    final postalCode = _addressValue(decoded, 'postalCode');
    final country = _addressValue(decoded, 'country');
    final countryCode = _countryCode(decoded['countryCode']);
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

  static Future<_AppleAddressResult> _requestAddressValue(
    double latitude,
    double longitude,
    String? localeIdentifier,
    int timeoutMilliseconds,
  ) {
    return _requestAddressValueWithOperations(
      latitude,
      longitude,
      localeIdentifier,
      timeoutMilliseconds,
      requestAddress: _nativeRequestAddress,
      allocate: _nativeAllocate,
      free: _nativeFree,
    );
  }

  static Future<_AppleAddressResult> _requestAddressValueWithOperations(
    double latitude,
    double longitude,
    String? localeIdentifier,
    int timeoutMilliseconds, {
    required void Function(
      double latitude,
      double longitude,
      Pointer<Uint8> localeIdentifier,
      int timeoutMilliseconds,
      Pointer<NativeFunction<Void Function(Pointer<Uint8>, Int32)>> callback,
    )
    requestAddress,
    required Pointer<Void> Function(int size) allocate,
    required void Function(Pointer<Void> value) free,
  }) {
    final completer = Completer<_AppleAddressResult>();
    late final NativeCallable<_AppleAddressCallbackNative> callback;
    callback = NativeCallable<_AppleAddressCallbackNative>.listener((
      Pointer<Uint8> addressJson,
      int failure,
    ) {
      callback.close();
      try {
        String? decodedAddress;
        if (addressJson != nullptr) {
          decodedAddress = utf8.decode(_nullTerminatedBytes(addressJson));
        }
        completer.complete((addressJson: decodedAddress, failure: failure));
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (addressJson != nullptr) free(addressJson.cast());
      }
    });

    Pointer<Uint8> localePointer = nullptr;
    try {
      if (localeIdentifier != null) {
        localePointer = _nativeUtf8(localeIdentifier, allocate);
      }
      requestAddress(
        latitude,
        longitude,
        localePointer,
        timeoutMilliseconds,
        callback.nativeFunction,
      );
    } on Object {
      callback.close();
      rethrow;
    } finally {
      if (localePointer != nullptr) free(localePointer.cast());
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

  static String? _addressValue(Map<String, Object?> values, String key) {
    final value = values[key];
    if (value == null) return null;
    if (value is! String) {
      throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      );
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _countryCode(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      );
    }
    final normalized = value.trim();
    if (!_isAsciiCountryCode(normalized)) return null;
    return normalized.toUpperCase();
  }

  static bool _isAsciiCountryCode(String value) {
    if (value.length != 2) return false;
    return value.codeUnits.every(
      (codeUnit) => (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122),
    );
  }

  static Pointer<Uint8> _nativeUtf8(
    String value,
    Pointer<Void> Function(int size) allocate,
  ) {
    final bytes = utf8.encode(value);
    final pointer = allocate(bytes.length + 1).cast<Uint8>();
    if (pointer == nullptr) {
      throw const DeviceLocationException(
        DeviceLocationExceptionReason.operationUnavailable,
      );
    }
    pointer.asTypedList(bytes.length + 1)
      ..setRange(0, bytes.length, bytes)
      ..[bytes.length] = 0;
    return pointer;
  }

  static List<int> _nullTerminatedBytes(Pointer<Uint8> pointer) {
    const maximumPayloadLength = 1024 * 1024;
    final bytes = <int>[];
    for (var index = 0; index < maximumPayloadLength; index += 1) {
      final byte = pointer[index];
      if (byte == 0) return bytes;
      bytes.add(byte);
    }
    throw const DeviceLocationException(
      DeviceLocationExceptionReason.operationUnavailable,
    );
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
  @Native<
    Void Function(
      Double,
      Double,
      Pointer<Uint8>,
      Int64,
      Pointer<NativeFunction<_AppleAddressCallbackNative>>,
    )
  >(symbol: 'omf_device_location_request_address')
  external static void _nativeRequestAddress(
    double latitude,
    double longitude,
    Pointer<Uint8> localeIdentifier,
    int timeoutMilliseconds,
    Pointer<NativeFunction<_AppleAddressCallbackNative>> callback,
  );

  @RecordUse()
  @Native<Pointer<Void> Function(IntPtr)>(
    symbol: 'omf_device_location_allocate',
  )
  external static Pointer<Void> _nativeAllocate(int size);

  @RecordUse()
  @Native<Void Function(Pointer<Void>)>(symbol: 'omf_device_location_free')
  external static void _nativeFree(Pointer<Void> pointer);

  @RecordUse()
  @Native<Void Function(Pointer<NativeFunction<_AppleValueCallbackNative>>)>(
    symbol: 'omf_device_location_open_settings',
  )
  external static void _nativeOpenSettings(
    Pointer<NativeFunction<_AppleValueCallbackNative>> callback,
  );

  static const _addressTimeoutMilliseconds = 30_000;
}
