import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_locale/device_locale_unsupported.dart';

void main() {
  test('when the platform is unsupported, it should return null', () {
    expect(DeviceLocalePlatformImplementation().getCountry(), completion(isNull));
  });
}
