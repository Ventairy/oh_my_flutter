import 'device_display/device_display.dart';
import 'device_location/device_location.dart';

/// Groups device utilities behind one injectable entry point.
///
/// Use the individual utilities directly when only one device capability is
/// needed, or retain a [Device] when several capabilities are used together.
///
/// ```dart
/// const device = Device();
/// final permission = await device.location.permissionStatus;
/// final radii = await device.display.cornerRadii(context);
/// ```
///
/// See the [device guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/device.md)
/// for choosing between the shared facade and individual utilities.
final class Device {
  /// Creates a collection of device utilities.
  ///
  /// Supply implementations to substitute device behavior in tests.
  const Device({
    this.location = const DeviceLocation(),
    this.display = const DeviceDisplay(),
  });

  /// Manages foreground location access and retrieves device location data.
  final DeviceLocation location;

  /// Provides information about and interaction with the device display.
  final DeviceDisplay display;
}
