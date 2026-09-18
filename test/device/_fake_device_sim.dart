part of 'device_test.dart';

class _FakeDeviceSim implements DeviceSim {
  const _FakeDeviceSim();

  @override
  Future<Country?> getCountry() async => Country.brazil;
}
