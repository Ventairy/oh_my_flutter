import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('DeviceLocationPermissionStatus', () {
    for (final permission in const [
      DeviceLocationPermissionStatus.whileInUse,
      DeviceLocationPermissionStatus.always,
    ]) {
      test(
        'when permission is ${permission.name}, it should be granted',
        () {
          expect(permission.isGranted, isTrue);
        },
      );
    }

    for (final permission in const [
      DeviceLocationPermissionStatus.notDetermined,
      DeviceLocationPermissionStatus.denied,
      DeviceLocationPermissionStatus.deniedForever,
      DeviceLocationPermissionStatus.restricted,
    ]) {
      test(
        'when permission is ${permission.name}, it should not be granted',
        () {
          expect(permission.isGranted, isFalse);
        },
      );
    }

    test(
      'when all permissions are inspected, it should expose the complete contract',
      () {
        expect(
          DeviceLocationPermissionStatus.values,
          const <DeviceLocationPermissionStatus>[
            DeviceLocationPermissionStatus.notDetermined,
            DeviceLocationPermissionStatus.denied,
            DeviceLocationPermissionStatus.deniedForever,
            DeviceLocationPermissionStatus.restricted,
            DeviceLocationPermissionStatus.whileInUse,
            DeviceLocationPermissionStatus.always,
          ],
        );
      },
    );
  });
}
