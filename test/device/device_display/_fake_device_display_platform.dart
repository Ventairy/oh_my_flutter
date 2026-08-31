part of 'device_display_test.dart';

final class _FakeDeviceDisplayPlatform extends DeviceDisplayPlatform {
  DeviceDisplayPlatformCornerRadii? cornerRadii;
  Exception? error;
  Completer<DeviceDisplayPlatformCornerRadii?>? completer;
  int requests = 0;
  (double, double, double, double)? requestedGeometry;

  @override
  Future<DeviceDisplayPlatformCornerRadii?> getCornerRadii({
    required double displayWidth,
    required double displayHeight,
    required double viewWidth,
    required double viewHeight,
    required bool hasSinglePlatformView,
  }) async {
    requests += 1;
    requestedGeometry = (
      displayWidth,
      displayHeight,
      viewWidth,
      viewHeight,
    );
    final pending = completer;
    if (pending != null) return pending.future;

    final requestError = error;
    if (requestError != null) throw requestError;
    return cornerRadii;
  }
}
