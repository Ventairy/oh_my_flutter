import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_display/device_display_unsupported.dart';

void main() {
  test(
    'when corner radii are requested on an unsupported platform, '
    'it should return null',
    () {
      final platform = DeviceDisplayPlatformImplementation();

      expect(
        platform.getCornerRadii(
          displayWidth: 780,
          displayHeight: 1688,
          viewWidth: 780,
          viewHeight: 1688,
          hasSinglePlatformView: true,
        ),
        completion(isNull),
      );
    },
  );
}
