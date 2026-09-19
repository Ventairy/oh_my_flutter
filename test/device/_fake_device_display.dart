part of 'device_test.dart';

final class _FakeDeviceDisplay implements DeviceDisplay {
  const new();

  @override
  Future<BorderRadius?> cornerRadii(BuildContext context) async {
    return BorderRadius.zero;
  }
}
