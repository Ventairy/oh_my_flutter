import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_accelerometer/pigeon_device_accelerometer.dart';
import 'package:oh_my_flutter/src/gen/device_accelerometer/device_accelerometer.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.oh_my_flutter.DeviceAccelerometerHostApi.isAvailable',
    DeviceAccelerometerHostApi.pigeonChannelCodec,
  );
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
  for (final available in [true, false]) {
    test('when native availability is $available, it should return that value', () {
      messenger.setMockDecodedMessageHandler(channel, (_) async => [available]);
      expect(PigeonDeviceAccelerometerPlatform().isAvailable, completion(available));
    });
  }
  for (final failure in {
    'sensorUnavailable': DeviceAccelerometerExceptionReason.sensorUnavailable,
    'permissionDenied': DeviceAccelerometerExceptionReason.permissionDenied,
    'unexpected': DeviceAccelerometerExceptionReason.operationUnavailable,
  }.entries) {
    test('when native access reports ${failure.key}, it should return a typed failure', () {
      messenger.setMockDecodedMessageHandler(channel, (_) async => [failure.key, 'failure', null]);
      expect(
        PigeonDeviceAccelerometerPlatform().isAvailable,
        throwsA(isA<DeviceAccelerometerException>().having((error) => error.reason, 'reason', failure.value)),
      );
    });
  }
  test('when native registration is missing, it should expose an operation failure', () {
    expect(
      PigeonDeviceAccelerometerPlatform().isAvailable,
      throwsA(
        isA<DeviceAccelerometerException>().having(
          (error) => error.reason,
          'reason',
          DeviceAccelerometerExceptionReason.operationUnavailable,
        ),
      ),
    );
  });
}
