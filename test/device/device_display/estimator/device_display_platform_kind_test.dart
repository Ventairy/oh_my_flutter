import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_display/estimator/device_display_estimator.dart';

void main() {
  group('DeviceDisplayPlatformKind', () {
    test('when values are inspected, it should expose both mobile families', () {
      expect(
        DeviceDisplayPlatformKind.values,
        const <DeviceDisplayPlatformKind>[
          DeviceDisplayPlatformKind.ios,
          DeviceDisplayPlatformKind.android,
        ],
      );
    });
  });
}
