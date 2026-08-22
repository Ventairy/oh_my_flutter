import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _scenario = String.fromEnvironment(
  'DEVICE_LOCATION_SCENARIO',
  defaultValue: 'granted',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'when Android grants location, it should return injected coordinates',
    (_) async {
      const location = DeviceLocation();
      final status = await location.permissionStatus;
      final coordinates = await location.getCurrentCoordinates(
        requestPermission: false,
      );

      expect(
        (
          isGranted: status.isGranted,
          latitude: coordinates.latitude.toStringAsFixed(4),
          longitude: coordinates.longitude.toStringAsFixed(4),
        ),
        (isGranted: true, latitude: '-23.5564', longitude: '-46.8441'),
      );
    },
    skip: _scenario != 'granted',
  );

  testWidgets(
    'when Android prompts for location, it should return the granted status',
    (_) async {
      final status = await const DeviceLocation().requestPermission();

      expect(status.isGranted, isTrue);
    },
    skip: _scenario != 'permissionRequest',
  );

  testWidgets(
    'when Android denies location, it should not prompt without permission',
    (_) async {
      Object? failure;
      try {
        await const DeviceLocation().getCurrentCoordinates(
          requestPermission: false,
        );
      } on DeviceLocationException catch (error) {
        failure = error.reason;
      }

      expect(failure, DeviceLocationExceptionReason.permissionDenied);
    },
    skip: _scenario != 'denied',
  );

  testWidgets(
    'when Android location services are disabled, it should report disabled',
    (_) async {
      Object? failure;
      try {
        await const DeviceLocation().getCurrentCoordinates(
          requestPermission: false,
        );
      } on DeviceLocationException catch (error) {
        failure = error.reason;
      }

      expect(failure, DeviceLocationExceptionReason.servicesDisabled);
    },
    skip: _scenario != 'servicesDisabled',
  );
}
