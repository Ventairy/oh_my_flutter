import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'when iOS provides foreground coordinates, it should return their values',
    (_) async {
      const location = DeviceLocation();
      final status = await location.permissionStatus;
      final coordinates = await location.getCurrentCoordinates();

      expect(
        (
          isGranted: status.isGranted,
          latitude: coordinates.latitude.toStringAsFixed(4),
          longitude: coordinates.longitude.toStringAsFixed(4),
        ),
        (
          isGranted: true,
          latitude: '-23.5564',
          longitude: '-46.8441',
        ),
      );
    },
  );

  testWidgets(
    'when iOS opens location settings, it should accept the navigation',
    (_) async {
      final opened = await const DeviceLocation().openLocationSettings();

      expect(opened, isTrue);
    },
  );
}
