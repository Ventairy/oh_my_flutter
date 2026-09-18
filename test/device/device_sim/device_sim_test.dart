import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_sim/device_sim_platform.dart';

part '_mock_device_sim_platform.dart';

void main() {
  late DeviceSimPlatform previous;
  late DeviceSimPlatform platform;

  setUp(() {
    previous = DeviceSimPlatform.instance;
    platform = _MockDeviceSimPlatform();
    DeviceSimPlatform.instance = platform;
  });
  tearDown(() => DeviceSimPlatform.instance = previous);

  for (final code in ['br', 'BR', ' br ']) {
    test('when the host returns "$code", it should return Brazil', () {
      when(() => platform.getCountry()).thenAnswer((_) async => code);
      expect(const DeviceSim().getCountry(), completion(Country.brazil));
    });
  }
  for (final code in <String?>[null, '', ' ', 'zz', 'BRA', '123']) {
    test('when the host returns "$code", it should return null', () {
      when(() => platform.getCountry()).thenAnswer((_) async => code);
      expect(const DeviceSim().getCountry(), completion(isNull));
    });
  }
  for (final error in <Object>[
    PlatformException(code: 'unavailable'),
    MissingPluginException(),
    StateError('unavailable'),
  ]) {
    test('when the lookup fails with ${error.runtimeType}, it should return null', () {
      when(() => platform.getCountry()).thenAnswer((_) => Future<String?>.error(error));
      expect(const DeviceSim().getCountry(), completion(isNull));
    });
  }
  test('when the SIM country changes, it should read the new country', () async {
    var code = 'br';
    when(() => platform.getCountry()).thenAnswer((_) async => code);
    final first = await const DeviceSim().getCountry();
    code = 'us';
    expect((first, await const DeviceSim().getCountry()), (Country.brazil, Country.unitedStates));
  });
}
