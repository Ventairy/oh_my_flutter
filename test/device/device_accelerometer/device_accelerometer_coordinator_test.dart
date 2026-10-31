import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_accelerometer/pigeon_device_accelerometer.dart';
import 'package:oh_my_flutter/src/gen/device_accelerometer/device_accelerometer.g.dart';

part '_fake_device_accelerometer_host.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeDeviceAccelerometerHost host;
  late StreamController<DeviceAccelerometerPlatformSample> source;
  late PigeonDeviceAccelerometerPlatform platform;
  late List<StreamSubscription<DeviceAccelerometerSample>> subscriptions;

  Future<void> flush() => Future<void>.delayed(Duration.zero);
  StreamSubscription<DeviceAccelerometerSample> listen({
    int interval = 200000,
    List<DeviceAccelerometerSample>? values,
    List<Object>? errors,
  }) {
    final subscription = platform
        .watch(samplingInterval: Duration(microseconds: interval))
        .listen(values?.add, onError: (Object error) => errors?.add(error));
    subscriptions.add(subscription);
    return subscription;
  }

  void emit(int time, {double x = 1}) =>
      source.add(DeviceAccelerometerPlatformSample(x: x, y: 2, z: 3, timestampMicroseconds: time));

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    host = _FakeDeviceAccelerometerHost();
    source = StreamController<DeviceAccelerometerPlatformSample>.broadcast();
    platform = PigeonDeviceAccelerometerPlatform.test(api: host, samples: () => source.stream);
    subscriptions = [];
  });
  tearDown(() async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await source.close();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('when watch is called without listening, it should remain inert', () async {
    platform.watch(samplingInterval: const Duration(milliseconds: 200));
    await flush();
    expect(host.configurations, isEmpty);
  });
  test('when a subscription starts, it should configure its interval', () async {
    listen();
    await flush();
    expect(host.configurations, [200000]);
  });
  test('when the same stream has two listeners, it should configure only one native source', () async {
    final stream = platform.watch(samplingInterval: const Duration(milliseconds: 200));
    subscriptions.addAll([stream.listen(null), stream.listen(null)]);
    await flush();
    expect(host.configurations, [200000]);
  });
  test('when a faster listener joins, it should request the faster interval', () async {
    listen();
    await flush();
    listen(interval: 20000);
    await flush();
    expect(host.configurations, [200000, 20000]);
  });
  test('when the faster listener cancels, it should restore the slower interval', () async {
    listen();
    final fast = listen(interval: 20000);
    await flush();
    await fast.cancel();
    expect(host.configurations.last, 200000);
  });
  test('when the final listener cancels, it should stop native sampling', () async {
    final subscription = listen();
    await flush();
    await subscription.cancel();
    expect(host.configurations, [200000, null]);
  });
  test('when cleanup is pending, it should await native cleanup before completing cancellation', () async {
    final stopped = Completer<void>();
    final subscription = listen();
    await flush();
    host.onConfigure = (interval) async {
      if (interval == null) await stopped.future;
    };
    var canceled = false;
    final cancel = subscription.cancel().then((_) => canceled = true);
    await flush();
    final beforeCleanup = canceled;
    stopped.complete();
    await cancel;
    expect(beforeCleanup, isFalse);
  });
  test('when canceled before startup runs, it should never configure native sampling', () async {
    await listen().cancel();
    expect(host.configurations, isEmpty);
  });
  test('when canceled during configuration, it should stop without attaching the source', () async {
    final starting = Completer<void>();
    host.onConfigure = (interval) async {
      if (interval != null) await starting.future;
    };
    final subscription = listen();
    await flush();
    final cancellation = subscription.cancel();
    starting.complete();
    await cancellation;
    expect(
      [host.configurations, source.hasListener],
      [
        [200000, null],
        false,
      ],
    );
  });
  test('when raw readings arrive, it should retain values and native measurement time', () async {
    final values = <DeviceAccelerometerSample>[];
    listen(values: values);
    await flush();
    emit(1234567);
    await flush();
    expect(values, [DeviceAccelerometerSample(x: 1, y: 2, z: 3, timestamp: const Duration(microseconds: 1234567))]);
  });
  test('when listeners request different rates, it should preserve each delivery cadence', () async {
    final slow = <DeviceAccelerometerSample>[];
    final fast = <DeviceAccelerometerSample>[];
    listen(interval: 200000, values: slow);
    listen(interval: 20000, values: fast);
    await flush();
    for (var time = 0; time <= 400000; time += 20000) {
      emit(time);
    }
    await flush();
    expect((slow.length, fast.length), (3, 21));
  });
  test('when readings are irregular, it should retain rolling deadlines rather than accumulate timing drift', () async {
    final values = <DeviceAccelerometerSample>[];
    listen(interval: 20000, values: values);
    await flush();
    [0, 16667, 33334, 50001, 66668, 83335, 100002].forEach(emit);
    await flush();
    expect(values.map((sample) => sample.timestamp.inMicroseconds), [0, 33334, 50001, 66668, 83335, 100002]);
  });
  test('when readings arrive before a subscription, it should not replay them', () async {
    source.add(DeviceAccelerometerPlatformSample(x: 5, y: 0, z: 0, timestampMicroseconds: 0));
    final values = <DeviceAccelerometerSample>[];
    listen(values: values);
    await flush();
    expect(values, isEmpty);
  });
  test('when a subscription pauses, it should follow standard buffering behavior', () async {
    final values = <DeviceAccelerometerSample>[];
    final subscription = listen(values: values);
    await flush();
    subscription.pause();
    emit(0);
    emit(200000);
    await flush();
    subscription.resume();
    await flush();
    await subscription.cancel();
    expect(values.length, 2);
  });
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    test('when lifecycle becomes ${state.name}, it should stop native sampling', () async {
      listen();
      await flush();
      binding.handleAppLifecycleStateChanged(state);
      await flush();
      expect(host.configurations.last, isNull);
    });
  }
  test('when the app resumes, it should retain listeners and deliver fresh timestamps', () async {
    final values = <DeviceAccelerometerSample>[];
    listen(values: values);
    await flush();
    emit(100);
    await flush();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await flush();
    emit(200);
    await flush();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush();
    emit(10000000);
    await flush();
    expect(values.map((sample) => sample.timestamp.inMicroseconds), [100, 10000000]);
  });
  test('when listening starts in the background, it should wait for resume', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    listen();
    await flush();
    expect(host.configurations, isEmpty);
  });
  test('when the source fails, it should emit a typed error and release access', () async {
    final errors = <Object>[];
    listen(errors: errors);
    await flush();
    source.addError(PlatformException(code: 'sensorUnavailable'));
    await flush();
    expect(
      [errors.single, host.configurations.last],
      [
        isA<DeviceAccelerometerException>().having(
          (error) => error.reason,
          'reason',
          DeviceAccelerometerExceptionReason.sensorUnavailable,
        ),
        null,
      ],
    );
  });
  test('when the source ends unexpectedly, it should close the consumer with a typed failure', () async {
    final errors = <Object>[];
    listen(errors: errors);
    await flush();
    await source.close();
    await flush();
    expect(errors, [isA<DeviceAccelerometerException>()]);
  });
  test('when configuration fails, it should close the subscription', () async {
    host.onConfigure = (_) async => throw PlatformException(code: 'permissionDenied');
    final errors = <Object>[];
    var closed = false;
    final subscription = listen(errors: errors)..onDone(() => closed = true);
    await flush();
    await subscription.cancel();
    expect((errors.length, closed), (1, true));
  });
  test('when access failed previously, it should allow a later retry', () async {
    host.onConfigure = (_) async => throw PlatformException(code: 'permissionDenied');
    listen();
    await flush();
    host.onConfigure = null;
    final values = <DeviceAccelerometerSample>[];
    listen(values: values);
    await flush();
    emit(0);
    await flush();
    expect(values.length, 1);
  });
  test('when native readings repeat or arrive out of order, it should ignore stale measurements', () async {
    final values = <DeviceAccelerometerSample>[];
    listen(interval: 1, values: values);
    await flush();
    [100, 100, 90, 110].forEach(emit);
    await flush();
    expect(values.map((sample) => sample.timestamp.inMicroseconds), [100, 110]);
  });
  test('when native data is nonfinite, it should report a typed failure', () async {
    final errors = <Object>[];
    listen(errors: errors);
    await flush();
    emit(0, x: double.nan);
    await flush();
    expect(errors, [isA<DeviceAccelerometerException>()]);
  });
}
