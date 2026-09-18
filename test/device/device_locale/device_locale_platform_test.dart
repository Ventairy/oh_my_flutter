import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_locale/device_locale_platform.dart';
import 'package:oh_my_flutter/src/device/device_locale/device_locale_unsupported.dart';

void main() {
  test('when the platform implementation is replaced, it should use the replacement', () {
    final previous = DeviceLocalePlatform.instance;
    addTearDown(() => DeviceLocalePlatform.instance = previous);
    DeviceLocalePlatform.instance = DeviceLocalePlatformImplementation();
    expect(DeviceLocalePlatform.instance.getCountry(), completion(isNull));
  });
}
