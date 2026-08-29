import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_location/device_location_c_library.dart';
import 'package:record_use/record_use.dart';

void main() {
  const dartLibrary = Library(
    'package:oh_my_flutter/src/device/device_location/apple_device_location/apple_device_location_platform.dart',
  );
  const platformClass = Class(
    'AppleDeviceLocationPlatform',
    dartLibrary,
  );
  const loadingUnit = LoadingUnit('app');
  const call = CallTearoff(loadingUnit: loadingUnit);

  test(
    'when no native calls are reachable, it should remove the location library',
    () {
      final recordings = Recordings(calls: const {}, instances: const {});

      expect(DeviceLocationCLibrary.isReachable(recordings), isFalse);
    },
  );

  test(
    'when another native feature is reachable, '
    'it should remove the location library',
    () {
      final recordings = Recordings(
        calls: {
          const Method(
            '_nativeRequestCamera',
            Class(
              'AppleDeviceCameraPlatform',
              Library(
                'package:oh_my_flutter/src/device/device_camera/apple_device_camera/apple_device_camera_platform.dart',
              ),
            ),
          ): [
            call,
          ],
        },
        instances: const {},
      );

      expect(DeviceLocationCLibrary.isReachable(recordings), isFalse);
    },
  );

  test(
    'when a location method has no reachable calls, '
    'it should remove the location library',
    () {
      final recordings = Recordings(
        calls: {
          const Method('_nativeRequestCoordinates', platformClass): [],
        },
        instances: const {},
      );

      expect(DeviceLocationCLibrary.isReachable(recordings), isFalse);
    },
  );

  for (final methodName in const [
    '_nativeIsServiceEnabled',
    '_nativeCheckPermission',
    '_nativeRequestPermission',
    '_nativeRequestCoordinates',
    '_nativeRequestAddress',
    '_nativeAllocate',
    '_nativeFree',
    '_nativeOpenSettings',
  ]) {
    test(
      'when $methodName is reachable, it should retain the location library',
      () {
        final recordings = Recordings(
          calls: {
            Method(methodName, platformClass): const [call],
          },
          instances: const {},
        );

        expect(DeviceLocationCLibrary.isReachable(recordings), isTrue);
      },
    );
  }
}
