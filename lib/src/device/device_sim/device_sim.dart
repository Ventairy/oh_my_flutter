import '../../country/country.dart';
import 'device_sim_platform.dart';

/// Provides access to the device's SIM capabilities.
///
/// Use this utility directly or through `Device.sim`.
/// See the [device SIM guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/device_sim.md)
/// for usage and platform availability.
interface class DeviceSim {
  /// Creates a utility for accessing the device's SIM capabilities.
  const DeviceSim();

  /// Finds the SIM provider's country.
  ///
  /// Android uses the system-default subscription, which may differ from the
  /// mobile-data subscription on a device with multiple SIMs. This country is
  /// not necessarily the device's current location or the user's phone region.
  ///
  /// Returns null when the country is unavailable or unrecognized, or the
  /// lookup fails. iOS, web, and desktop return null. No permission is requested
  /// and no locale or location fallback is applied.
  /// Each call reads the current value; applications choose their own fallback.
  Future<Country?> getCountry() async {
    try {
      final code = await DeviceSimPlatform.instance.getCountry();
      return code == null ? null : Country.tryFromIso2(code);
    } on Object {
      return null;
    }
  }
}
