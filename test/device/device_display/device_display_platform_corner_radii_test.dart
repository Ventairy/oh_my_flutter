import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_display/device_display_platform_corner_radii.dart';

void main() {
  test(
    'when corner radii are created, it should preserve every physical value',
    () {
      const cornerRadii = DeviceDisplayPlatformCornerRadii(
        topLeft: 10,
        topRight: 20,
        bottomRight: 30,
        bottomLeft: 40,
      );

      expect(
        (
          cornerRadii.topLeft,
          cornerRadii.topRight,
          cornerRadii.bottomRight,
          cornerRadii.bottomLeft,
        ),
        (10, 20, 30, 40),
      );
    },
  );
}
