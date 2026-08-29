import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_location/device_location_unsupported.dart';

void main() {
  final platform = DeviceLocationPlatformImplementation();
  const coordinates = DeviceLocationCoordinates(
    latitude: 0,
    longitude: 0,
    accuracy: 0,
  );

  for (final operation in <String, Future<Object?> Function()>{
    'checking location services': platform.isServiceEnabled,
    'checking permission': platform.checkPermission,
    'requesting permission': platform.requestPermission,
    'requesting coordinates': platform.getCurrentCoordinates,
    'requesting an address': () => platform.getAddress(
      coordinates: coordinates,
      localeIdentifier: null,
    ),
    'opening location settings': platform.openLocationSettings,
  }.entries) {
    test(
      'when ${operation.key} on an unsupported platform, '
      'it should report unsupportedPlatform',
      () async {
        expect(
          operation.value(),
          throwsA(
            isA<DeviceLocationException>().having(
              (exception) => exception.reason,
              'reason',
              DeviceLocationExceptionReason.unsupportedPlatform,
            ),
          ),
        );
      },
    );
  }
}
