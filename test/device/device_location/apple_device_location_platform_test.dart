import 'dart:convert';
import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_location/apple_device_location/apple_device_location_platform.dart';

void main() {
  const coordinates = DeviceLocationCoordinates(
    latitude: -23.556391,
    longitude: -46.844076,
    accuracy: 8.5,
  );

  AppleDeviceLocationPlatform createPlatform({
    ({int value, int failure}) service = const (value: 1, failure: 0),
    ({int value, int failure}) permission = const (value: 3, failure: 0),
    ({int value, int failure}) requestedPermission = const (
      value: 3,
      failure: 0,
    ),
    ({double latitude, double longitude, double accuracy, int failure}) coordinateResult = const (
      latitude: -23.556391,
      longitude: -46.844076,
      accuracy: 8.5,
      failure: 0,
    ),
    ({int value, int failure}) settings = const (value: 1, failure: 0),
    ({String? addressJson, int failure}) addressResult = const (
      addressJson: '{"street":"Rua Harmonia"}',
      failure: 0,
    ),
    void Function(
      double latitude,
      double longitude,
      String? localeIdentifier,
      int timeoutMilliseconds,
    )?
    onGetAddress,
  }) {
    return AppleDeviceLocationPlatform.test(
      isServiceEnabled: () async => service,
      checkPermission: () async => permission,
      requestPermission: () async => requestedPermission,
      getCurrentCoordinates: () async => coordinateResult,
      getAddress: (latitude, longitude, localeIdentifier, timeoutMilliseconds) async {
        onGetAddress?.call(
          latitude,
          longitude,
          localeIdentifier,
          timeoutMilliseconds,
        );
        return addressResult;
      },
      openLocationSettings: () async => settings,
    );
  }

  for (final enabled in [false, true]) {
    test(
      'when iOS reports service enabled as $enabled, it should return $enabled',
      () async {
        final platform = createPlatform(
          service: (value: enabled ? 1 : 0, failure: 0),
        );

        expect(platform.isServiceEnabled(), completion(enabled));
      },
    );
  }

  for (final entry in const <int, DeviceLocationPermissionStatus>{
    0: DeviceLocationPermissionStatus.notDetermined,
    1: DeviceLocationPermissionStatus.deniedForever,
    2: DeviceLocationPermissionStatus.restricted,
    3: DeviceLocationPermissionStatus.whileInUse,
    4: DeviceLocationPermissionStatus.always,
  }.entries) {
    test(
      'when iOS reports permission ${entry.key}, it should map ${entry.value.name}',
      () async {
        final platform = createPlatform(
          permission: (value: entry.key, failure: 0),
        );

        expect(platform.checkPermission(), completion(entry.value));
      },
    );
  }

  test(
    'when iOS reports an unknown permission, it should report operationUnavailable',
    () async {
      final platform = createPlatform(
        permission: const (value: -1, failure: 0),
      );

      expect(
        platform.checkPermission(),
        throwsA(
          isA<DeviceLocationException>().having(
            (exception) => exception.reason,
            'reason',
            DeviceLocationExceptionReason.operationUnavailable,
          ),
        ),
      );
    },
  );

  test(
    'when requesting iOS permission, it should map the native result',
    () async {
      final platform = createPlatform(
        requestedPermission: const (value: 2, failure: 0),
      );

      expect(
        platform.requestPermission(),
        completion(DeviceLocationPermissionStatus.restricted),
      );
    },
  );

  test(
    'when iOS returns valid coordinates, it should map them',
    () async {
      expect(
        createPlatform().getCurrentCoordinates(),
        completion(coordinates),
      );
    },
  );

  test(
    'when iOS returns an address, it should map and normalize every field',
    () async {
      final platform = createPlatform(
        addressResult: const (
          addressJson: r'''
{
  "formattedAddress":"  Rua Harmonia, 797\nSão Paulo - SP  ",
  "name":" Edifício Harmonia ",
  "street":" Rua Harmonia ",
  "streetNumber":" 797 ",
  "neighborhood":" Vila Madalena ",
  "district":" São Paulo ",
  "city":" São Paulo ",
  "state":" SP ",
  "postalCode":" 05435-001 ",
  "country":" Brasil ",
  "countryCode":" br "
}''',
          failure: 0,
        ),
      );

      expect(
        platform.getAddress(
          coordinates: coordinates,
          localeIdentifier: 'pt-BR',
        ),
        completion(
          const DeviceLocationAddress(
            coordinates: coordinates,
            formattedAddress: 'Rua Harmonia, 797\nSão Paulo - SP',
            name: 'Edifício Harmonia',
            street: 'Rua Harmonia',
            streetNumber: '797',
            neighborhood: 'Vila Madalena',
            district: 'São Paulo',
            city: 'São Paulo',
            state: 'SP',
            postalCode: '05435-001',
            country: 'Brasil',
            countryCode: 'BR',
          ),
        ),
      );
    },
  );

  test(
    'when the native address bridge returns JSON, '
    'it should decode it and release every allocation',
    () async {
      final process = DynamicLibrary.process();
      final systemAllocate = process.lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>(
        'malloc',
      );
      final systemFree = process.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('free');
      final allocatedAddresses = <int>[];
      final allocatedSizes = <int>[];
      final freedAddresses = <int>[];
      String? receivedLocale;
      int? receivedTimeoutMilliseconds;
      int? localeTerminator;

      Pointer<Void> allocate(int size) {
        final pointer = systemAllocate(size);
        allocatedAddresses.add(pointer.address);
        allocatedSizes.add(size);
        return pointer;
      }

      void free(Pointer<Void> pointer) {
        freedAddresses.add(pointer.address);
        systemFree(pointer);
      }

      String decodeNativeString(Pointer<Uint8> pointer) {
        final bytes = <int>[];
        for (var index = 0; pointer[index] != 0; index += 1) {
          bytes.add(pointer[index]);
        }
        return utf8.decode(bytes);
      }

      final platform = AppleDeviceLocationPlatform.test(
        isServiceEnabled: () async => const (value: 1, failure: 0),
        checkPermission: () async => const (value: 3, failure: 0),
        requestPermission: () async => const (value: 3, failure: 0),
        getCurrentCoordinates: () async => const (
          latitude: -23.556391,
          longitude: -46.844076,
          accuracy: 8.5,
          failure: 0,
        ),
        requestAddress:
            (
              _,
              _,
              localeIdentifier,
              timeoutMilliseconds,
              callback,
            ) {
              receivedLocale = decodeNativeString(localeIdentifier);
              receivedTimeoutMilliseconds = timeoutMilliseconds;
              localeTerminator = localeIdentifier[utf8.encode(receivedLocale!).length];
              final bytes = utf8.encode(
                '{"street":"Rua Harmonia","countryCode":"br"}',
              );
              final resultPointer = allocate(bytes.length + 1).cast<Uint8>();
              resultPointer.asTypedList(bytes.length + 1)
                ..setRange(0, bytes.length, bytes)
                ..[bytes.length] = 0;
              callback.asFunction<void Function(Pointer<Uint8>, int)>()(
                resultPointer,
                0,
              );
            },
        allocate: allocate,
        free: free,
        openLocationSettings: () async => const (value: 1, failure: 0),
      );

      final address = await platform.getAddress(
        coordinates: coordinates,
        localeIdentifier: 'pt-BR',
      );

      expect(
        (
          locale: receivedLocale,
          localeAllocationSize: allocatedSizes.first,
          localeTerminator: localeTerminator,
          timeoutMilliseconds: receivedTimeoutMilliseconds,
          street: address.street,
          countryCode: address.countryCode,
          allocations: allocatedAddresses.length,
          frees: freedAddresses.length,
          releasedEveryAllocation: allocatedAddresses.toSet().difference(freedAddresses.toSet()).isEmpty,
        ),
        (
          locale: 'pt-BR',
          localeAllocationSize: 6,
          localeTerminator: 0,
          timeoutMilliseconds: 30_000,
          street: 'Rua Harmonia',
          countryCode: 'BR',
          allocations: 2,
          frees: 2,
          releasedEveryAllocation: true,
        ),
      );
    },
  );

  test(
    'when iOS address lookup starts, it should forward coordinates and locale',
    () async {
      ({
        double latitude,
        double longitude,
        String? localeIdentifier,
        int timeoutMilliseconds,
      })?
      request;
      final platform = createPlatform(
        onGetAddress: (latitude, longitude, localeIdentifier, timeoutMilliseconds) {
          request = (
            latitude: latitude,
            longitude: longitude,
            localeIdentifier: localeIdentifier,
            timeoutMilliseconds: timeoutMilliseconds,
          );
        },
      );

      await platform.getAddress(
        coordinates: coordinates,
        localeIdentifier: 'pt-BR',
      );

      expect(
        request,
        const (
          latitude: -23.556391,
          longitude: -46.844076,
          localeIdentifier: 'pt-BR',
          timeoutMilliseconds: 30_000,
        ),
      );
    },
  );

  for (final entry in const <String, String?>{
    'missing payload': null,
    'malformed JSON': '{',
    'non-object JSON': '[]',
    'non-string field': '{"street":42}',
    'empty fields': '{"street":"   "}',
  }.entries) {
    test(
      'when iOS returns ${entry.key}, it should report operationUnavailable',
      () async {
        final platform = createPlatform(
          addressResult: (addressJson: entry.value, failure: 0),
        );

        expect(
          platform.getAddress(
            coordinates: coordinates,
            localeIdentifier: null,
          ),
          throwsA(
            isA<DeviceLocationException>().having(
              (exception) => exception.reason,
              'reason',
              DeviceLocationExceptionReason.operationUnavailable,
            ),
          ),
        );
      },
    );
  }

  for (final countryCode in ['1x', 'éx', 'ß']) {
    test(
      'when iOS returns invalid country code $countryCode, it should omit it',
      () async {
        final platform = createPlatform(
          addressResult: (
            addressJson: '{"city":"São Paulo","countryCode":"$countryCode"}',
            failure: 0,
          ),
        );

        final address = await platform.getAddress(
          coordinates: coordinates,
          localeIdentifier: null,
        );

        expect(address.countryCode, isNull);
      },
    );
  }

  test(
    'when iOS address lookup fails, it should map operationUnavailable',
    () async {
      final platform = createPlatform(
        addressResult: const (addressJson: null, failure: 5),
      );

      expect(
        platform.getAddress(
          coordinates: coordinates,
          localeIdentifier: null,
        ),
        throwsA(
          isA<DeviceLocationException>().having(
            (exception) => exception.reason,
            'reason',
            DeviceLocationExceptionReason.operationUnavailable,
          ),
        ),
      );
    },
  );

  for (final entry in <String, ({double latitude, double longitude, double accuracy})>{
    'non-finite latitude': (
      latitude: double.nan,
      longitude: 0,
      accuracy: 1,
    ),
    'out-of-range longitude': (
      latitude: 0,
      longitude: 181,
      accuracy: 1,
    ),
    'negative accuracy': (
      latitude: 0,
      longitude: 0,
      accuracy: -1,
    ),
  }.entries) {
    test(
      'when iOS returns ${entry.key}, it should report coordinatesUnavailable',
      () async {
        final platform = createPlatform(
          coordinateResult: (
            latitude: entry.value.latitude,
            longitude: entry.value.longitude,
            accuracy: entry.value.accuracy,
            failure: 0,
          ),
        );

        expect(
          platform.getCurrentCoordinates(),
          throwsA(
            isA<DeviceLocationException>().having(
              (exception) => exception.reason,
              'reason',
              DeviceLocationExceptionReason.coordinatesUnavailable,
            ),
          ),
        );
      },
    );
  }

  for (final entry in const <int, DeviceLocationExceptionReason>{
    1: DeviceLocationExceptionReason.servicesDisabled,
    2: DeviceLocationExceptionReason.permissionDenied,
    3: DeviceLocationExceptionReason.permissionPermanentlyDenied,
    4: DeviceLocationExceptionReason.configurationMissing,
    5: DeviceLocationExceptionReason.operationUnavailable,
    6: DeviceLocationExceptionReason.coordinatesUnavailable,
  }.entries) {
    test(
      'when iOS reports failure ${entry.key}, it should map ${entry.value.name}',
      () async {
        final platform = createPlatform(
          coordinateResult: (
            latitude: 0,
            longitude: 0,
            accuracy: 0,
            failure: entry.key,
          ),
        );

        expect(
          platform.getCurrentCoordinates(),
          throwsA(
            isA<DeviceLocationException>().having(
              (exception) => exception.reason,
              'reason',
              entry.value,
            ),
          ),
        );
      },
    );
  }

  for (final opened in [false, true]) {
    test(
      'when iOS settings navigation reports $opened, it should return $opened',
      () async {
        final platform = createPlatform(
          settings: (value: opened ? 1 : 0, failure: 0),
        );

        expect(platform.openLocationSettings(), completion(opened));
      },
    );
  }

  test(
    'when iOS settings navigation fails, it should report operationUnavailable',
    () async {
      final platform = createPlatform(
        settings: const (value: 0, failure: 5),
      );

      expect(
        platform.openLocationSettings(),
        throwsA(
          isA<DeviceLocationException>().having(
            (exception) => exception.reason,
            'reason',
            DeviceLocationExceptionReason.operationUnavailable,
          ),
        ),
      );
    },
  );
}
