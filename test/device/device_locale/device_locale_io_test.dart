@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_locale/device_locale_io.dart';
import 'package:oh_my_flutter/src/gen/device_locale/device_locale.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.oh_my_flutter.DeviceLocaleHostApi.getCountry',
    DeviceLocaleHostApi.pigeonChannelCodec,
  );
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockDecodedMessageHandler(channel, null));

  test('when selecting the operating system implementation, it should use supported native hosts only', () {
    messenger.setMockDecodedMessageHandler(channel, (_) async => ['br']);
    final supported = Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows;
    expect(DeviceLocalePlatformImplementation().getCountry(), completion(supported ? 'br' : null));
  });
}
