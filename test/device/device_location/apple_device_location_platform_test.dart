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
  }) {
    return AppleDeviceLocationPlatform.test(
      isServiceEnabled: () async => service,
      checkPermission: () async => permission,
      requestPermission: () async => requestedPermission,
      getCurrentCoordinates: () async => coordinateResult,
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
