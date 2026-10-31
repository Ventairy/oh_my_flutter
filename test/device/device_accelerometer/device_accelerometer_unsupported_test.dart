import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_accelerometer/device_accelerometer_unsupported.dart';

void main() {
  final platform = DeviceAccelerometerPlatformImplementation();
  test('when the platform is unsupported, it should report no accelerometer', () {
    expect(platform.isAvailable, completion(isFalse));
  });
  test('when watching an unsupported platform, it should emit a typed error and finish', () {
    expect(
      platform.watch(samplingInterval: const Duration(milliseconds: 200)),
      emitsInOrder([
        emitsError(
          isA<DeviceAccelerometerException>().having(
            (error) => error.reason,
            'reason',
            DeviceAccelerometerExceptionReason.unsupportedPlatform,
          ),
        ),
        emitsDone,
      ]),
    );
  });
  test('when an unsupported stream is reused, it should support multiple listeners', () async {
    final stream = platform.watch(samplingInterval: const Duration(milliseconds: 200));
    final results = await Future.wait([
      stream.toList().then<Object>((_) => 'unexpected', onError: (Object error) => error),
      stream.toList().then<Object>((_) => 'unexpected', onError: (Object error) => error),
    ]);
    expect(results, everyElement(isA<DeviceAccelerometerException>()));
  });
}
