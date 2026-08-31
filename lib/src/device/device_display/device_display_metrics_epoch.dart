part of 'device_display.dart';

final class _DeviceDisplayMetricsEpoch with WidgetsBindingObserver {
  _DeviceDisplayMetricsEpoch() {
    WidgetsBinding.instance.addObserver(this);
  }

  static _DeviceDisplayMetricsEpoch? _instance;

  static int get current {
    return (_instance ??= _DeviceDisplayMetricsEpoch())._value;
  }

  int _value = 0;

  @override
  void didChangeMetrics() {
    _value += 1;
  }
}
