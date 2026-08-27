import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'when iOS backgrounds an active permission prompt, it should resolve it',
    (_) async {
      const location = DeviceLocation();
      final permissionRequest = location.requestPermission();
      await Future<void>.delayed(const Duration(seconds: 1));
      final opened = await location.openLocationSettings();

      DeviceLocationExceptionReason? failure;
      try {
        await permissionRequest;
      } on DeviceLocationException catch (error) {
        failure = error.reason;
      }

      expect(
        (opened: opened, failure: failure),
        (
          opened: true,
          failure: DeviceLocationExceptionReason.operationUnavailable,
        ),
      );
      debugPrint('OH_MY_FLUTTER_IOS_PERMISSION_LIFECYCLE_COMPLETE');
    },
  );
}
