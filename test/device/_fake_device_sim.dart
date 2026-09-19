part of 'device_test.dart';

class _FakeDeviceSim implements DeviceSim {
  const new();

  @override
  Future<Country?> getCountry() async => Country.brazil;
}
