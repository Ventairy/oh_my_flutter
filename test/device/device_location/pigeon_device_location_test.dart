import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_location/pigeon/android_device_location.g.dart';
import 'package:oh_my_flutter/src/device/device_location/pigeon_device_location.dart';

part '_mock_android_device_location_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AndroidDeviceLocationApi api;
  late PigeonDeviceLocationPlatform platform;

  setUp(() {
    api = _MockAndroidDeviceLocationApi();
    platform = PigeonDeviceLocationPlatform.test(api);
  });

  test(
    'when Android reports its service state, it should return that state',
    () async {
      when(api.isServiceEnabled).thenAnswer((_) async => true);

      expect(platform.isServiceEnabled(), completion(isTrue));
    },
  );

  for (final entry in <AndroidDeviceLocationPermissionStatus, DeviceLocationPermissionStatus>{
    AndroidDeviceLocationPermissionStatus.denied: DeviceLocationPermissionStatus.denied,
    AndroidDeviceLocationPermissionStatus.deniedForever: DeviceLocationPermissionStatus.deniedForever,
    AndroidDeviceLocationPermissionStatus.whileInUse: DeviceLocationPermissionStatus.whileInUse,
  }.entries) {
    test(
      'when Android reports ${entry.key.name}, it should map that permission',
      () async {
        when(api.checkPermission).thenAnswer((_) async => entry.key);

        expect(platform.checkPermission(), completion(entry.value));
      },
    );
  }

  test(
    'when Android grants requested permission, it should map that permission',
    () async {
      when(api.requestPermission).thenAnswer(
        (_) async => AndroidDeviceLocationPermissionStatus.whileInUse,
      );

      expect(
        platform.requestPermission(),
        completion(DeviceLocationPermissionStatus.whileInUse),
      );
    },
  );

  test(
    'when Android returns coordinates, it should map them',
    () async {
      when(api.getCurrentCoordinates).thenAnswer(
        (_) async => AndroidDeviceCoordinates(
          latitude: -23.556391,
          longitude: -46.844076,
          accuracy: 8.5,
        ),
      );

      expect(
        platform.getCurrentCoordinates(),
        completion(
          const DeviceLocationCoordinates(
            latitude: -23.556391,
            longitude: -46.844076,
            accuracy: 8.5,
          ),
        ),
      );
    },
  );

  for (final entry in <String, AndroidDeviceCoordinates>{
    'non-finite latitude': AndroidDeviceCoordinates(
      latitude: double.nan,
      longitude: 0,
      accuracy: 1,
    ),
    'out-of-range longitude': AndroidDeviceCoordinates(
      latitude: 0,
      longitude: 181,
      accuracy: 1,
    ),
    'negative accuracy': AndroidDeviceCoordinates(
      latitude: 0,
      longitude: 0,
      accuracy: -1,
    ),
  }.entries) {
    test(
      'when Android returns ${entry.key}, it should report coordinatesUnavailable',
      () async {
        when(api.getCurrentCoordinates).thenAnswer((_) async => entry.value);

        expect(
          platform.getCurrentCoordinates(),
          throwsA(
            isA<DeviceLocationException>().having(
              (exception) => exception.reason,
              'reason',
              DeviceLocationExceptionReason.coordinatesUnavailable,
            ),
          ),
        );
      },
    );
  }

  for (final entry in <AndroidDeviceLocationFailure, DeviceLocationExceptionReason>{
    AndroidDeviceLocationFailure.servicesDisabled: DeviceLocationExceptionReason.servicesDisabled,
    AndroidDeviceLocationFailure.permissionDenied: DeviceLocationExceptionReason.permissionDenied,
    AndroidDeviceLocationFailure.permissionPermanentlyDenied: DeviceLocationExceptionReason.permissionPermanentlyDenied,
    AndroidDeviceLocationFailure.configurationMissing: DeviceLocationExceptionReason.configurationMissing,
    AndroidDeviceLocationFailure.operationUnavailable: DeviceLocationExceptionReason.operationUnavailable,
    AndroidDeviceLocationFailure.coordinatesUnavailable: DeviceLocationExceptionReason.coordinatesUnavailable,
  }.entries) {
    test(
      'when Android reports ${entry.key.name}, it should map that failure',
      () async {
        when(api.getCurrentCoordinates).thenAnswer(
          (_) async => throw PlatformException(
            code: 'nativeError',
            details: entry.key,
          ),
        );

        expect(
          platform.getCurrentCoordinates(),
          throwsA(
            isA<DeviceLocationException>().having(
              (exception) => exception.reason,
              'reason',
              entry.value,
            ),
          ),
        );
      },
    );
  }

  test(
    'when Android omits typed details, it should map the failure code',
    () async {
      when(api.getCurrentCoordinates).thenAnswer(
        (_) async => throw PlatformException(code: 'coordinatesUnavailable'),
      );

      expect(
        platform.getCurrentCoordinates(),
        throwsA(
          isA<DeviceLocationException>().having(
            (exception) => exception.reason,
            'reason',
            DeviceLocationExceptionReason.coordinatesUnavailable,
          ),
        ),
      );
    },
  );

  test(
    'when the generated channel is unavailable, it should report operationUnavailable',
    () async {
      when(api.getCurrentCoordinates).thenAnswer(
        (_) async => throw PlatformException(code: 'channel-error'),
      );

      expect(
        platform.getCurrentCoordinates(),
        throwsA(
          isA<DeviceLocationException>().having(
            (exception) => exception.reason,
            'reason',
            DeviceLocationExceptionReason.operationUnavailable,
          ),
        ),
      );
    },
  );

  test(
    'when Android reports a typed failure, it should preserve its cause',
    () async {
      final error = PlatformException(
        code: 'permissionDenied',
        details: AndroidDeviceLocationFailure.permissionDenied,
      );
      when(api.getCurrentCoordinates).thenAnswer((_) async => throw error);

      expect(
        platform.getCurrentCoordinates(),
        throwsA(
          isA<DeviceLocationException>().having(
            (exception) => exception.cause,
            'cause',
            same(error),
          ),
        ),
      );
    },
  );

  test(
    'when Android opens location settings, it should return true',
    () async {
      when(api.openLocationSettings).thenAnswer((_) async => true);

      expect(platform.openLocationSettings(), completion(isTrue));
    },
  );

  test(
    'when settings channel fails, it should report operationUnavailable',
    () async {
      when(api.openLocationSettings).thenAnswer(
        (_) async => throw PlatformException(code: 'channel-error'),
      );

      expect(
        platform.openLocationSettings(),
        throwsA(
          isA<DeviceLocationException>().having(
            (exception) => exception.reason,
            'reason',
            DeviceLocationExceptionReason.operationUnavailable,
          ),
        ),
      );
    },
  );

  test(
    'when a typed failure crosses the codec, it should remain typed',
    () async {
      const channelName =
          'dev.flutter.pigeon.oh_my_flutter.'
          'AndroidDeviceLocationApi.getCurrentCoordinates';
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = BasicMessageChannel<Object?>(
        channelName,
        AndroidDeviceLocationApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler(
        channel,
        (_) async => <Object?>[
          'permissionDenied',
          null,
          AndroidDeviceLocationFailure.permissionDenied,
        ],
      );
      addTearDown(
        () => messenger.setMockDecodedMessageHandler(channel, null),
      );
      final generatedApi = AndroidDeviceLocationApi(
        binaryMessenger: messenger,
      );

      expect(
        generatedApi.getCurrentCoordinates(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.details,
            'details',
            AndroidDeviceLocationFailure.permissionDenied,
          ),
        ),
      );
    },
  );
}
