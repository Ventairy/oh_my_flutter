@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_accelerometer/device_accelerometer_io.dart';
import 'package:oh_my_flutter/src/gen/device_accelerometer/device_accelerometer.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.oh_my_flutter.DeviceAccelerometerHostApi.isAvailable',
    DeviceAccelerometerHostApi.pigeonChannelCodec,
  );
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
  test('when selecting an operating system, it should use native hosts only on Android and iOS', () {
    messenger.setMockDecodedMessageHandler(channel, (_) async => [true]);
    expect(DeviceAccelerometerPlatformImplementation().isAvailable, completion(Platform.isAndroid || Platform.isIOS));
  });
}
