import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_locale/pigeon_device_locale.dart';
import 'package:oh_my_flutter/src/gen/device_locale/device_locale.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.oh_my_flutter.DeviceLocaleHostApi.getCountry',
    DeviceLocaleHostApi.pigeonChannelCodec,
  );
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockDecodedMessageHandler(channel, null));

  for (final code in <String?>['br', null]) {
    test('when the host returns "$code", it should preserve the response', () {
      messenger.setMockDecodedMessageHandler(channel, (_) async => [code]);
      expect(PigeonDeviceLocalePlatform().getCountry(), completion(code));
    });
  }
  test('when a test API is supplied, it should use that API', () {
    messenger.setMockDecodedMessageHandler(channel, (_) async => ['us']);
    expect(PigeonDeviceLocalePlatform.test(DeviceLocaleHostApi()).getCountry(), completion('us'));
  });
  test('when the channel is missing, it should report failure to the capability', () {
    expect(PigeonDeviceLocalePlatform().getCountry(), throwsA(isA<PlatformException>()));
  });
}
