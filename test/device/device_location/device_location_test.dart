import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_location/device_location_platform.dart';

part '_fake_device_location_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Matcher hasReason(DeviceLocationExceptionReason reason) {
    return isA<DeviceLocationException>().having(
      (exception) => exception.reason,
      'reason',
      reason,
    );
  }

  group('DeviceLocation', () {
    late DeviceLocationPlatform originalPlatform;
    late _FakeDeviceLocationPlatform platform;

    setUp(() {
      originalPlatform = DeviceLocationPlatform.instance;
      platform = _FakeDeviceLocationPlatform();
      DeviceLocationPlatform.instance = platform;
    });

    tearDown(() {
      DeviceLocationPlatform.instance = originalPlatform;
    });

    test(
      'when permission status is checked, it should return the native status',
      () async {
        platform.checkedPermission = DeviceLocationPermissionStatus.restricted;

        expect(
          const DeviceLocation().permissionStatus,
          completion(DeviceLocationPermissionStatus.restricted),
        );
      },
    );

    test(
      'when permission status is checked, it should not request permission',
      () async {
        await const DeviceLocation().permissionStatus;

        expect(platform.permissionRequests, 0);
      },
    );

    test(
      'when a permission status check fails, it should report operationUnavailable',
      () async {
        platform.checkPermissionError = Exception('unavailable');

        expect(
          const DeviceLocation().permissionStatus,
          throwsA(hasReason(DeviceLocationExceptionReason.operationUnavailable)),
        );
      },
    );

    test(
      'when permission is not determined, it should request permission',
      () async {
        platform.checkedPermission = DeviceLocationPermissionStatus.notDetermined;

        await const DeviceLocation().requestPermission();

        expect(platform.permissionRequests, 1);
      },
    );

    test(
      'when permission remains denied, it should return denied',
      () async {
        platform
          ..checkedPermission = DeviceLocationPermissionStatus.denied
          ..requestedPermission = DeviceLocationPermissionStatus.denied;

        expect(
          const DeviceLocation().requestPermission(),
          completion(DeviceLocationPermissionStatus.denied),
        );
      },
    );

    for (final permission in const [
      DeviceLocationPermissionStatus.deniedForever,
      DeviceLocationPermissionStatus.restricted,
      DeviceLocationPermissionStatus.whileInUse,
      DeviceLocationPermissionStatus.always,
    ]) {
      test(
        'when permission is ${permission.name}, it should not request it again',
        () async {
          platform.checkedPermission = permission;

          await const DeviceLocation().requestPermission();

          expect(platform.permissionRequests, 0);
        },
      );
    }

    test(
      'when services are disabled, permission request should remain independent',
      () async {
        platform
          ..serviceEnabled = false
          ..checkedPermission = DeviceLocationPermissionStatus.notDetermined;

        await const DeviceLocation().requestPermission();

        expect(platform.serviceChecks, 0);
      },
    );

    test(
      'when permission requests overlap, it should show one native prompt',
      () async {
        final completer = Completer<DeviceLocationPermissionStatus>();
        platform
          ..checkedPermission = DeviceLocationPermissionStatus.notDetermined
          ..permissionCompleter = completer;

        final first = const DeviceLocation().requestPermission();
        final second = const DeviceLocation().requestPermission();
        completer.complete(DeviceLocationPermissionStatus.whileInUse);
        await Future.wait([first, second]);

        expect(platform.permissionRequests, 1);
      },
    );

    test(
      'when permission request fails, it should report operationUnavailable',
      () async {
        platform
          ..checkedPermission = DeviceLocationPermissionStatus.notDetermined
          ..permissionRequestError = Exception('unavailable');

        expect(
          const DeviceLocation().requestPermission(),
          throwsA(hasReason(DeviceLocationExceptionReason.operationUnavailable)),
        );
      },
    );

    test(
      'when permission is granted, it should return current coordinates',
      () async {
        final coordinates = await const DeviceLocation().getCurrentCoordinates();

        expect(coordinates, platform.coordinates);
      },
    );

    test(
      'when permission is missing by default, it should request permission',
      () async {
        platform.checkedPermission = DeviceLocationPermissionStatus.notDetermined;

        await const DeviceLocation().getCurrentCoordinates();

        expect(platform.permissionRequests, 1);
      },
    );

    test(
      'when automatic permission is disabled, it should not request permission',
      () async {
        platform.checkedPermission = DeviceLocationPermissionStatus.denied;

        try {
          await const DeviceLocation().getCurrentCoordinates(
            requestPermission: false,
          );
        } on DeviceLocationException {
          // Expected permission failure.
        }

        expect(platform.permissionRequests, 0);
      },
    );

    for (final permission in const [
      DeviceLocationPermissionStatus.notDetermined,
      DeviceLocationPermissionStatus.denied,
    ]) {
      test(
        'when $permission is not requested, it should report permissionDenied',
        () async {
          platform.checkedPermission = permission;

          expect(
            const DeviceLocation().getCurrentCoordinates(
              requestPermission: false,
            ),
            throwsA(hasReason(DeviceLocationExceptionReason.permissionDenied)),
          );
        },
      );
    }

    for (final permission in const [
      DeviceLocationPermissionStatus.deniedForever,
      DeviceLocationPermissionStatus.restricted,
    ]) {
      test(
        'when $permission blocks coordinates, it should report permissionPermanentlyDenied',
        () async {
          platform.checkedPermission = permission;

          expect(
            const DeviceLocation().getCurrentCoordinates(),
            throwsA(
              hasReason(DeviceLocationExceptionReason.permissionPermanentlyDenied),
            ),
          );
        },
      );
    }

    test(
      'when location services are disabled, it should report servicesDisabled',
      () async {
        platform.serviceEnabled = false;

        expect(
          const DeviceLocation().getCurrentCoordinates(),
          throwsA(hasReason(DeviceLocationExceptionReason.servicesDisabled)),
        );
      },
    );

    test(
      'when coordinate acquisition fails, it should report coordinatesUnavailable',
      () async {
        platform.coordinatesError = Exception('unavailable');

        expect(
          const DeviceLocation().getCurrentCoordinates(),
          throwsA(hasReason(DeviceLocationExceptionReason.coordinatesUnavailable)),
        );
      },
    );

    test(
      'when native coordinates report permission denial, it should preserve that failure',
      () async {
        platform.coordinatesError = const DeviceLocationException(
          DeviceLocationExceptionReason.permissionDenied,
        );

        expect(
          const DeviceLocation().getCurrentCoordinates(),
          throwsA(hasReason(DeviceLocationExceptionReason.permissionDenied)),
        );
      },
    );

    test(
      'when coordinate requests overlap, it should acquire coordinates once',
      () async {
        final completer = Completer<DeviceLocationCoordinates>();
        platform.coordinatesCompleter = completer;

        final first = const DeviceLocation().getCurrentCoordinates();
        final second = const DeviceLocation().getCurrentCoordinates();
        completer.complete(platform.coordinates);
        await Future.wait([first, second]);

        expect(platform.coordinatesRequests, 1);
      },
    );

    test(
      'when acquisition completes, it should let the next call refresh',
      () async {
        await const DeviceLocation().getCurrentCoordinates();
        await const DeviceLocation().getCurrentCoordinates();

        expect(platform.coordinatesRequests, 2);
      },
    );

    test(
      'when the platform changes during a request, it should use the captured platform',
      () async {
        final replacement = _FakeDeviceLocationPlatform()
          ..coordinates = const DeviceLocationCoordinates(
            latitude: 1,
            longitude: 2,
            accuracy: 3,
          );
        platform.onServiceEnabled = () {
          DeviceLocationPlatform.instance = replacement;
        };

        final coordinates = await const DeviceLocation().getCurrentCoordinates();

        expect(coordinates, platform.coordinates);
      },
    );

    for (final opened in [true, false]) {
      test(
        'when settings navigation returns $opened, it should return $opened',
        () async {
          platform.settingsOpened = opened;

          expect(
            const DeviceLocation().openLocationSettings(),
            completion(opened),
          );
        },
      );
    }

    test(
      'when settings navigation fails, it should report operationUnavailable',
      () async {
        platform.settingsError = Exception('unavailable');

        expect(
          const DeviceLocation().openLocationSettings(),
          throwsA(hasReason(DeviceLocationExceptionReason.operationUnavailable)),
        );
      },
    );
  });
}
