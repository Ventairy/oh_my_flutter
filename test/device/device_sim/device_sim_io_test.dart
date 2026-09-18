@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_sim/device_sim_io.dart';

void main() {
  test('when the operating system is unsupported, it should return null', () {
    expect(DeviceSimPlatformImplementation().getCountry(), completion(isNull));
  }, skip: Platform.isAndroid);
}
