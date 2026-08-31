import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_display/estimator/device_display_estimator.dart';

void main() {
  group('DeviceDisplayMetrics', () {
    test('when optional evidence is omitted, it should use neutral defaults', () {
      const metrics = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.ios,
        displaySize: Size(390, 844),
        viewSize: Size(390, 844),
        devicePixelRatio: 3,
      );

      expect(
        metrics,
        isA<DeviceDisplayMetrics>()
            .having((value) => value.viewPadding, 'viewPadding', EdgeInsets.zero)
            .having(
              (value) => value.systemGestureInsets,
              'systemGestureInsets',
              EdgeInsets.zero,
            )
            .having(
              (value) => value.displayCutoutBounds,
              'displayCutoutBounds',
              isNull,
            )
            .having(
              (value) => value.displayCutoutCount,
              'displayCutoutCount',
              0,
            )
            .having(
              (value) => value.hasFoldOrHinge,
              'hasFoldOrHinge',
              isFalse,
            ),
      );
    });
  });
}
