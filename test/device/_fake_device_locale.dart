part of 'device_test.dart';

class _FakeDeviceLocale implements DeviceLocale {
  const new();

  @override
  Future<Country?> getCountry() async => Country.brazil;
}
