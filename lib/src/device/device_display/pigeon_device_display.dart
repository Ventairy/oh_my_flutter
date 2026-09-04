import 'package:meta/meta.dart';

import 'device_display_platform.dart';
import 'device_display_platform_corner_radii.dart';
import 'pigeon/device_display.g.dart';

/// Retrieves display geometry through the generated mobile host API.
final class PigeonDeviceDisplayPlatform extends DeviceDisplayPlatform {
  /// Creates the mobile device-display platform implementation.
  PigeonDeviceDisplayPlatform() : _api = DeviceDisplayHostApi();

  /// Creates an implementation backed by a test host API.
  @visibleForTesting
  PigeonDeviceDisplayPlatform.test(this._api);

  final DeviceDisplayHostApi _api;

  @override
  Future<DeviceDisplayPlatformCornerRadii?> getCornerRadii({
    required double displayWidth,
    required double displayHeight,
    required double viewWidth,
    required double viewHeight,
    required bool hasSinglePlatformView,
  }) async {
    if (!hasSinglePlatformView) return null;

    final DeviceDisplayCornerRadiiMessage? cornerRadii;
    try {
      cornerRadii = await _api.getCornerRadii(
        DeviceDisplayGeometryMessage(
          displayWidth: displayWidth,
          displayHeight: displayHeight,
          viewWidth: viewWidth,
          viewHeight: viewHeight,
        ),
      );
    } on Object {
      return null;
    }
    if (cornerRadii == null || !_isValid(cornerRadii)) return null;

    return DeviceDisplayPlatformCornerRadii(
      topLeft: cornerRadii.topLeft,
      topRight: cornerRadii.topRight,
      bottomRight: cornerRadii.bottomRight,
      bottomLeft: cornerRadii.bottomLeft,
    );
  }

  bool _isValid(DeviceDisplayCornerRadiiMessage cornerRadii) {
    return cornerRadii.topLeft.isFinite &&
        cornerRadii.topLeft >= 0 &&
        cornerRadii.topRight.isFinite &&
        cornerRadii.topRight >= 0 &&
        cornerRadii.bottomRight.isFinite &&
        cornerRadii.bottomRight >= 0 &&
        cornerRadii.bottomLeft.isFinite &&
        cornerRadii.bottomLeft >= 0;
  }
}
