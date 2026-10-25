import 'package:code_assets/code_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_c_library.dart';
import 'package:record_use/record_use.dart';

void main() {
  test('when tracing is built for Android, it should link the system math library', () {
    expect(ContourNativePortCLibrary.libraryFor(OS.android).libraries, ['m']);
  });

  test('when host tracing is built for macOS, it should use the platform math implementation', () {
    expect(ContourNativePortCLibrary.libraryFor(OS.macOS).libraries, isEmpty);
  });

  test('when tracing is built for Android, it should keep the C++ runtime self contained', () {
    expect(ContourNativePortCLibrary.libraryFor(OS.android).cppLinkStdLib, 'c++_static');
  });

  test('when contour code is compiled, it should request C++17 explicitly', () {
    expect(ContourNativePortCLibrary.libraryFor(OS.macOS).std, 'c++17');
  });

  test('when the C++ implementation is compiled, it should compile SDK C glue separately', () {
    expect(
      ContourNativePortCLibrary.libraryFor(OS.macOS).sources,
      isNot(contains('src/contour_native_port/sdk/include/dart_api_dl.c')),
    );
  });

  const sessionLibrary = Library(
    'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session_io.dart',
  );
  const sessionClass = Class('ContourNativePortSession', sessionLibrary);
  const create = Method('create', sessionClass);
  const call = CallTearoff(loadingUnit: LoadingUnit('app'));

  test(
    'when reachability metadata is unavailable, '
    'it should retain the native library',
    () {
      expect(ContourNativePortCLibrary.isReachable(null), isTrue);
    },
  );

  test(
    'when no session creation is reachable, '
    'it should omit the native library',
    () {
      final recordings = Recordings(calls: {}, instances: const {});

      expect(ContourNativePortCLibrary.isReachable(recordings), isFalse);
    },
  );

  test(
    'when session creation has no reachable calls, '
    'it should omit the native library',
    () {
      final recordings = Recordings(
        calls: {create: const []},
        instances: const {},
      );

      expect(ContourNativePortCLibrary.isReachable(recordings), isFalse);
    },
  );

  test(
    'when another native feature is reachable, '
    'it should omit the contour native library',
    () {
      final recordings = Recordings(
        calls: {
          const Method(
            '_nativeRequestCoordinates',
            Class(
              'AppleDeviceLocationPlatform',
              Library(
                'package:oh_my_flutter/src/device/device_location/apple_device_location/apple_device_location_platform.dart',
              ),
            ),
          ): [
            call,
          ],
        },
        instances: const {},
      );

      expect(ContourNativePortCLibrary.isReachable(recordings), isFalse);
    },
  );

  test(
    'when a matching class belongs to another library, '
    'it should omit the native library',
    () {
      final recordings = Recordings(
        calls: {
          const Method(
            'create',
            Class(
              'ContourNativePortSession',
              Library('package:another_package/session.dart'),
            ),
          ): [
            call,
          ],
        },
        instances: const {},
      );

      expect(ContourNativePortCLibrary.isReachable(recordings), isFalse);
    },
  );

  test(
    'when a different session member is reachable, '
    'it should omit the native library',
    () {
      final recordings = Recordings(
        calls: {
          const Method('isSupported', sessionClass): const [call],
        },
        instances: const {},
      );

      expect(ContourNativePortCLibrary.isReachable(recordings), isFalse);
    },
  );

  test(
    'when native session creation is reachable, '
    'it should retain the native library',
    () {
      final recordings = Recordings(
        calls: {
          create: [call],
        },
        instances: const {},
      );

      expect(ContourNativePortCLibrary.isReachable(recordings), isTrue);
    },
  );
}
