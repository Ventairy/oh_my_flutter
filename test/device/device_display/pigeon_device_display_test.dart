import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oh_my_flutter/src/device/device_display/device_display_platform_corner_radii.dart';
import 'package:oh_my_flutter/src/device/device_display/pigeon/android_device_display.g.dart';
import 'package:oh_my_flutter/src/device/device_display/pigeon_device_display.dart';

part '_mock_android_device_display_api.dart';

void main() {
  late AndroidDeviceDisplayApi api;
  late PigeonDeviceDisplayPlatform platform;

  setUpAll(() {
    registerFallbackValue(
      AndroidDeviceDisplayGeometry(
        displayWidth: 0,
        displayHeight: 0,
        viewWidth: 0,
        viewHeight: 0,
      ),
    );
  });

  setUp(() {
    api = _MockAndroidDeviceDisplayApi();
    platform = PigeonDeviceDisplayPlatform.test(api);
  });

  Future<DeviceDisplayPlatformCornerRadii?> readCornerRadii({
    bool hasSinglePlatformView = true,
  }) {
    return platform.getCornerRadii(
      displayWidth: 780,
      displayHeight: 1688,
      viewWidth: 780,
      viewHeight: 1688,
      hasSinglePlatformView: hasSinglePlatformView,
    );
  }

  test(
    'when Android returns corner radii, it should preserve every physical value',
    () async {
      when(() => api.getCornerRadii(any())).thenAnswer(
        (_) async => AndroidDeviceDisplayCornerRadii(
          topLeft: 10,
          topRight: 20,
          bottomRight: 30,
          bottomLeft: 40,
        ),
      );

      final cornerRadii = await readCornerRadii();

      expect(
        (
          cornerRadii?.topLeft,
          cornerRadii?.topRight,
          cornerRadii?.bottomRight,
          cornerRadii?.bottomLeft,
        ),
        (10, 20, 30, 40),
      );
    },
  );

  test(
    'when Android returns no corner radii, it should return null',
    () async {
      when(() => api.getCornerRadii(any())).thenAnswer((_) async => null);

      expect(readCornerRadii(), completion(isNull));
    },
  );

  test(
    'when Android evidence is requested, it should send the Flutter view geometry',
    () async {
      when(() => api.getCornerRadii(any())).thenAnswer((_) async => null);

      await readCornerRadii();
      final geometry =
          verify(
                () => api.getCornerRadii(captureAny()),
              ).captured.single
              as AndroidDeviceDisplayGeometry;

      expect(
        (
          geometry.displayWidth,
          geometry.displayHeight,
          geometry.viewWidth,
          geometry.viewHeight,
        ),
        (780, 1688, 780, 1688),
      );
    },
  );

  test(
    'when multiple Flutter views exist, it should not query the Android window',
    () async {
      await readCornerRadii(hasSinglePlatformView: false);

      verifyNever(() => api.getCornerRadii(any()));
    },
  );

  test(
    'when Android returns zero corner radii, it should preserve every zero',
    () async {
      when(() => api.getCornerRadii(any())).thenAnswer(
        (_) async => AndroidDeviceDisplayCornerRadii(
          topLeft: 0,
          topRight: 0,
          bottomRight: 0,
          bottomLeft: 0,
        ),
      );

      final cornerRadii = await readCornerRadii();

      expect(
        (
          cornerRadii?.topLeft,
          cornerRadii?.topRight,
          cornerRadii?.bottomRight,
          cornerRadii?.bottomLeft,
        ),
        (0, 0, 0, 0),
      );
    },
  );

  for (final entry in <String, AndroidDeviceDisplayCornerRadii>{
    'a non-finite top-left radius': AndroidDeviceDisplayCornerRadii(
      topLeft: double.nan,
      topRight: 0,
      bottomRight: 0,
      bottomLeft: 0,
    ),
    'a non-finite top-right radius': AndroidDeviceDisplayCornerRadii(
      topLeft: 0,
      topRight: double.infinity,
      bottomRight: 0,
      bottomLeft: 0,
    ),
    'a negative bottom-right radius': AndroidDeviceDisplayCornerRadii(
      topLeft: 0,
      topRight: 0,
      bottomRight: -1,
      bottomLeft: 0,
    ),
  }.entries) {
    test(
      'when Android returns ${entry.key}, it should return null',
      () async {
        when(() => api.getCornerRadii(any())).thenAnswer(
          (_) async => entry.value,
        );

        expect(readCornerRadii(), completion(isNull));
      },
    );
  }

  test(
    'when the Android channel fails, it should return null',
    () async {
      when(() => api.getCornerRadii(any())).thenAnswer(
        (_) async => throw PlatformException(code: 'channel-error'),
      );

      expect(readCornerRadii(), completion(isNull));
    },
  );
}
