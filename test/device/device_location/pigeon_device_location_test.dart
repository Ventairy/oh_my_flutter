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

  test(
    'when Android returns an address, it should map and normalize every field',
    () async {
      when(
        () => api.getAddress(-23.556391, -46.844076, 'pt-BR', 30_000),
      ).thenAnswer(
        (_) async => AndroidDeviceLocationAddress(
          formattedAddress: '  Rua Harmonia, 797\nSão Paulo - SP  ',
          name: ' Edifício Harmonia ',
          street: ' Rua Harmonia ',
          streetNumber: ' 797 ',
          neighborhood: ' Vila Madalena ',
          district: ' São Paulo ',
          city: ' São Paulo ',
          state: ' SP ',
          postalCode: ' 05435-001 ',
          country: ' Brasil ',
          countryCode: ' br ',
        ),
      );

      expect(
        platform.getAddress(
          coordinates: const DeviceLocationCoordinates(
            latitude: -23.556391,
            longitude: -46.844076,
            accuracy: 8.5,
          ),
          localeIdentifier: 'pt-BR',
        ),
        completion(
          const DeviceLocationAddress(
            coordinates: DeviceLocationCoordinates(
              latitude: -23.556391,
              longitude: -46.844076,
              accuracy: 8.5,
            ),
            formattedAddress: 'Rua Harmonia, 797\nSão Paulo - SP',
            name: 'Edifício Harmonia',
            street: 'Rua Harmonia',
            streetNumber: '797',
            neighborhood: 'Vila Madalena',
            district: 'São Paulo',
            city: 'São Paulo',
            state: 'SP',
            postalCode: '05435-001',
            country: 'Brasil',
            countryCode: 'BR',
          ),
        ),
      );
    },
  );

  test(
    'when Android returns no usable address fields, it should report operationUnavailable',
    () async {
      when(
        () => api.getAddress(0, 0, null, 30_000),
      ).thenAnswer(
        (_) async => AndroidDeviceLocationAddress(street: '   '),
      );

      expect(
        platform.getAddress(
          coordinates: const DeviceLocationCoordinates(
            latitude: 0,
            longitude: 0,
            accuracy: 0,
          ),
          localeIdentifier: null,
        ),
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

  for (final countryCode in ['1x', 'éx', 'ß']) {
    test(
      'when Android returns invalid country code $countryCode, it should omit it',
      () async {
        when(
          () => api.getAddress(0, 0, null, 30_000),
        ).thenAnswer(
          (_) async => AndroidDeviceLocationAddress(
            city: 'São Paulo',
            countryCode: countryCode,
          ),
        );

        final address = await platform.getAddress(
          coordinates: const DeviceLocationCoordinates(
            latitude: 0,
            longitude: 0,
            accuracy: 0,
          ),
          localeIdentifier: null,
        );

        expect(address.countryCode, isNull);
      },
    );
  }

  test(
    'when Android returns a malformed address reply, it should report operationUnavailable',
    () async {
      final error = StateError('malformed platform reply');
      when(() => api.getAddress(0, 0, null, 30_000)).thenThrow(error);

      expect(
        platform.getAddress(
          coordinates: const DeviceLocationCoordinates(
            latitude: 0,
            longitude: 0,
            accuracy: 0,
          ),
          localeIdentifier: null,
        ),
        throwsA(
          isA<DeviceLocationException>()
              .having(
                (exception) => exception.reason,
                'reason',
                DeviceLocationExceptionReason.operationUnavailable,
              )
              .having((exception) => exception.cause, 'cause', same(error)),
        ),
      );
    },
  );

  test(
    'when Android address lookup fails, it should map operationUnavailable',
    () async {
      when(
        () => api.getAddress(0, 0, null, 30_000),
      ).thenAnswer(
        (_) async => throw PlatformException(code: 'operationUnavailable'),
      );

      expect(
        platform.getAddress(
          coordinates: const DeviceLocationCoordinates(
            latitude: 0,
            longitude: 0,
            accuracy: 0,
          ),
          localeIdentifier: null,
        ),
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

  test(
    'when a malformed address value crosses the codec, it should report operationUnavailable',
    () async {
      const channelName =
          'dev.flutter.pigeon.oh_my_flutter.'
          'AndroidDeviceLocationApi.getAddress';
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = BasicMessageChannel<Object?>(
        channelName,
        AndroidDeviceLocationApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler(
        channel,
        (_) async => <Object?>[42],
      );
      addTearDown(
        () => messenger.setMockDecodedMessageHandler(channel, null),
      );
      final malformedPlatform = PigeonDeviceLocationPlatform.test(
        AndroidDeviceLocationApi(binaryMessenger: messenger),
      );

      expect(
        malformedPlatform.getAddress(
          coordinates: const DeviceLocationCoordinates(
            latitude: 0,
            longitude: 0,
            accuracy: 0,
          ),
          localeIdentifier: null,
        ),
        throwsA(
          isA<DeviceLocationException>()
              .having(
                (exception) => exception.reason,
                'reason',
                DeviceLocationExceptionReason.operationUnavailable,
              )
              .having((exception) => exception.cause, 'cause', isA<TypeError>()),
        ),
      );
    },
  );

  test(
    'when malformed coordinates cross the codec, it should report operationUnavailable',
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
        (_) async => <Object?>[42],
      );
      addTearDown(
        () => messenger.setMockDecodedMessageHandler(channel, null),
      );
      final malformedPlatform = PigeonDeviceLocationPlatform.test(
        AndroidDeviceLocationApi(binaryMessenger: messenger),
      );

      expect(
        malformedPlatform.getCurrentCoordinates(),
        throwsA(
          isA<DeviceLocationException>()
              .having(
                (exception) => exception.reason,
                'reason',
                DeviceLocationExceptionReason.operationUnavailable,
              )
              .having((exception) => exception.cause, 'cause', isA<TypeError>()),
        ),
      );
    },
  );
}
