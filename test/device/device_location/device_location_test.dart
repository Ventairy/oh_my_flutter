import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_location/device_location_platform.dart';

part '_fake_device_location_platform.dart';
part '_fake_device_location.dart';

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
      'when a consumer implements DeviceLocation, it should support test substitution',
      () {
        expect(const _FakeDeviceLocation(), isA<DeviceLocation>());
      },
    );

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
      'when an address is available, it should return its components',
      () async {
        final address = await const DeviceLocation().getCurrentAddress();

        expect(address.street, 'Rua Harmonia');
      },
    );

    test(
      'when an address locale is supplied, it should forward its language tag',
      () async {
        await const DeviceLocation().getCurrentAddress(
          locale: const Locale('pt', 'BR'),
        );

        expect(platform.localeIdentifier, 'pt-BR');
      },
    );

    test(
      'when an address locale has a script, it should forward a BCP-47 tag',
      () async {
        await const DeviceLocation().getCurrentAddress(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        );

        expect(platform.localeIdentifier, 'zh-Hant-TW');
      },
    );

    test(
      'when address permission is not requested, it should not show a prompt',
      () async {
        platform.checkedPermission = DeviceLocationPermissionStatus.denied;

        try {
          await const DeviceLocation().getCurrentAddress(
            requestPermission: false,
          );
        } on DeviceLocationException {
          // Expected permission failure.
        }

        expect(platform.permissionRequests, 0);
      },
    );

    test(
      'when address lookup fails, it should report operationUnavailable',
      () async {
        platform.addressError = Exception('unavailable');

        expect(
          const DeviceLocation().getCurrentAddress(),
          throwsA(hasReason(DeviceLocationExceptionReason.operationUnavailable)),
        );
      },
    );

    test(
      'when address lookup throws a non-exception object, it should report operationUnavailable',
      () async {
        platform.addressErrorObject = StateError('malformed platform response');

        expect(
          const DeviceLocation().getCurrentAddress(),
          throwsA(hasReason(DeviceLocationExceptionReason.operationUnavailable)),
        );
      },
    );

    test(
      'when address coordinate acquisition fails, it should preserve that failure',
      () async {
        platform.coordinatesError = const DeviceLocationException(
          DeviceLocationExceptionReason.coordinatesUnavailable,
        );

        expect(
          const DeviceLocation().getCurrentAddress(),
          throwsA(hasReason(DeviceLocationExceptionReason.coordinatesUnavailable)),
        );
      },
    );

    test(
      'when address coordinate acquisition returns malformed platform data, it should report operationUnavailable',
      () async {
        platform.coordinatesErrorObject = StateError(
          'malformed platform response',
        );

        expect(
          const DeviceLocation().getCurrentAddress(),
          throwsA(
            hasReason(DeviceLocationExceptionReason.operationUnavailable),
          ),
        );
      },
    );

    test(
      'when address location services are disabled, it should preserve that failure',
      () async {
        platform.serviceEnabled = false;

        expect(
          const DeviceLocation().getCurrentAddress(),
          throwsA(hasReason(DeviceLocationExceptionReason.servicesDisabled)),
        );
      },
    );

    test(
      'when native address lookup reports a typed failure, it should preserve it',
      () async {
        platform.addressError = const DeviceLocationException(
          DeviceLocationExceptionReason.unsupportedPlatform,
        );

        expect(
          const DeviceLocation().getCurrentAddress(),
          throwsA(hasReason(DeviceLocationExceptionReason.unsupportedPlatform)),
        );
      },
    );

    test(
      'when matching address requests overlap, it should reverse geocode once',
      () async {
        final coordinatesCompleter = Completer<DeviceLocationCoordinates>();
        final addressCompleter = Completer<DeviceLocationAddress>();
        platform
          ..coordinatesCompleter = coordinatesCompleter
          ..addressCompleter = addressCompleter;

        final first = const DeviceLocation().getCurrentAddress();
        final second = const DeviceLocation().getCurrentAddress();
        coordinatesCompleter.complete(platform.coordinates);
        await Future<void>.delayed(Duration.zero);
        addressCompleter.complete(platform.address);
        await Future.wait([first, second]);

        expect(platform.addressRequests, 1);
      },
    );

    test(
      'when pending address requests have equal nonidentical coordinates, '
      'it should reverse geocode independently',
      () async {
        final firstCoordinatesCompleter = Completer<DeviceLocationCoordinates>();
        final secondCoordinatesCompleter = Completer<DeviceLocationCoordinates>();
        final addressCompleter = Completer<DeviceLocationAddress>();
        final firstCoordinates = DeviceLocationCoordinates(
          latitude: platform.coordinates.latitude,
          longitude: platform.coordinates.longitude,
          accuracy: platform.coordinates.accuracy,
        );
        final secondCoordinates = DeviceLocationCoordinates(
          latitude: platform.coordinates.latitude,
          longitude: platform.coordinates.longitude,
          accuracy: platform.coordinates.accuracy,
        );
        platform
          ..coordinatesCompleter = firstCoordinatesCompleter
          ..addressCompleter = addressCompleter;

        final first = const DeviceLocation().getCurrentAddress();
        firstCoordinatesCompleter.complete(firstCoordinates);
        await Future<void>.delayed(Duration.zero);
        platform.coordinatesCompleter = secondCoordinatesCompleter;

        final second = const DeviceLocation().getCurrentAddress();
        secondCoordinatesCompleter.complete(secondCoordinates);
        await Future<void>.delayed(Duration.zero);
        addressCompleter.complete(platform.address);
        await Future.wait([first, second]);

        expect(
          (
            coordinates: platform.coordinatesRequests,
            addresses: platform.addressRequests,
          ),
          (coordinates: 2, addresses: 2),
        );
      },
    );

    test(
      'when address requests capture different platforms, '
      'it should reverse geocode independently',
      () async {
        final firstCoordinatesCompleter = Completer<DeviceLocationCoordinates>();
        final firstAddressCompleter = Completer<DeviceLocationAddress>();
        final secondAddressCompleter = Completer<DeviceLocationAddress>();
        final replacement = _FakeDeviceLocationPlatform()..addressCompleter = secondAddressCompleter;
        platform
          ..coordinatesCompleter = firstCoordinatesCompleter
          ..addressCompleter = firstAddressCompleter;

        final first = const DeviceLocation().getCurrentAddress();
        DeviceLocationPlatform.instance = replacement;
        final second = const DeviceLocation().getCurrentAddress();
        firstCoordinatesCompleter.complete(platform.coordinates);
        await Future<void>.delayed(Duration.zero);
        firstAddressCompleter.complete(platform.address);
        secondAddressCompleter.complete(replacement.address);
        await Future.wait([first, second]);

        expect(
          (
            first: platform.addressRequests,
            second: replacement.addressRequests,
          ),
          (first: 1, second: 1),
        );
      },
    );

    test(
      'when address locales differ, it should reverse geocode independently',
      () async {
        final coordinatesCompleter = Completer<DeviceLocationCoordinates>();
        platform.coordinatesCompleter = coordinatesCompleter;

        final portuguese = const DeviceLocation().getCurrentAddress(
          locale: const Locale('pt', 'BR'),
        );
        final english = const DeviceLocation().getCurrentAddress(
          locale: const Locale('en', 'US'),
        );
        coordinatesCompleter.complete(platform.coordinates);
        await Future.wait([portuguese, english]);

        expect(platform.addressRequests, 2);
      },
    );

    test(
      'when address lookup completes, it should let the next call refresh',
      () async {
        await const DeviceLocation().getCurrentAddress();
        await const DeviceLocation().getCurrentAddress();

        expect(platform.addressRequests, 2);
      },
    );

    test(
      'when the platform changes during address acquisition, it should use the captured platform',
      () async {
        final replacement = _FakeDeviceLocationPlatform();
        platform.onServiceEnabled = () {
          DeviceLocationPlatform.instance = replacement;
        };

        final address = await const DeviceLocation().getCurrentAddress();

        expect(address, platform.address);
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
