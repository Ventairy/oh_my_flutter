import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/device_accelerometer_example.dart';

part '_fake_device_accelerometer.dart';

void main() {
  late StreamController<DeviceAccelerometerSample> source;
  setUp(() => source = StreamController<DeviceAccelerometerSample>.broadcast());
  tearDown(() => source.close());

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: DeviceAccelerometerExample(accelerometer: _FakeDeviceAccelerometer(source))),
    ),
  );

  testWidgets('when the example starts, it should wait for an explicit interaction', (tester) async {
    await show(tester);
    expect(source.hasListener, isFalse);
  });
  testWidgets('when start is tapped, it should observe acceleration', (tester) async {
    await show(tester);
    await tester.tap(find.text('Start accelerometer'));
    await tester.pump();
    source.add(DeviceAccelerometerSample(x: 1, y: 2, z: 3, timestamp: const Duration(seconds: 5)));
    await tester.pump();
    expect(find.text('X 1.00 · Y 2.00 · Z 3.00 m/s²'), findsOneWidget);
  });
  testWidgets('when samples advance, it should display elapsed measurement time', (tester) async {
    await show(tester);
    await tester.tap(find.text('Start accelerometer'));
    source.add(DeviceAccelerometerSample(x: 0, y: 0, z: 9.81, timestamp: const Duration(seconds: 5)));
    await tester.pump();
    source.add(DeviceAccelerometerSample(x: 0, y: 0, z: 9.81, timestamp: const Duration(milliseconds: 5200)));
    await tester.pump();
    expect(find.text('Sample time: 200 ms'), findsOneWidget);
  });
  testWidgets('when stop is tapped, it should release observation', (tester) async {
    await show(tester);
    await tester.tap(find.text('Start accelerometer'));
    await tester.pump();
    await tester.tap(find.text('Stop accelerometer'));
    await tester.pump();
    expect(source.hasListener, isFalse);
  });
  testWidgets('when hardware is missing, it should explain the outcome', (tester) async {
    await show(tester);
    await tester.tap(find.text('Start accelerometer'));
    source.addError(const DeviceAccelerometerException(DeviceAccelerometerExceptionReason.sensorUnavailable));
    await tester.pump();
    expect(find.text('No accelerometer is available on this device.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('when the example is disposed, it should cancel its subscription', (tester) async {
    await show(tester);
    await tester.tap(find.text('Start accelerometer'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(source.hasListener, isFalse);
  });
}
