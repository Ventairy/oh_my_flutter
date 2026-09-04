part of 'device_test.dart';

final class _FakeDeviceDisplay implements DeviceDisplay {
  const _FakeDeviceDisplay();

  @override
  Future<BorderRadius?> cornerRadii(BuildContext context) async {
    return BorderRadius.zero;
  }
}
