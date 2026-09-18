part of 'device_test.dart';

class _FakeDeviceLocale implements DeviceLocale {
  const _FakeDeviceLocale();

  @override
  Future<Country?> getCountry() async => Country.brazil;
}
