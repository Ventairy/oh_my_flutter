import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('DeviceLocationExceptionReason', () {
    test(
      'when all reasons are inspected, it should expose the complete contract',
      () {
        expect(
          DeviceLocationExceptionReason.values,
          const <DeviceLocationExceptionReason>[
            DeviceLocationExceptionReason.servicesDisabled,
            DeviceLocationExceptionReason.permissionDenied,
            DeviceLocationExceptionReason.permissionPermanentlyDenied,
            DeviceLocationExceptionReason.configurationMissing,
            DeviceLocationExceptionReason.unsupportedPlatform,
            DeviceLocationExceptionReason.operationUnavailable,
            DeviceLocationExceptionReason.coordinatesUnavailable,
          ],
        );
      },
    );
  });
}
