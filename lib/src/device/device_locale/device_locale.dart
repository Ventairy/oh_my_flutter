import '../../country/country.dart';
import 'device_locale_platform.dart';

/// Helps applications use the device's language and regional preferences.
///
/// Use this utility directly or through `Device.locale`.
/// See the [device locale guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/device_locale.md)
/// for usage and platform availability.
interface class DeviceLocale {
  /// Creates a utility for accessing device locale preferences.
  const DeviceLocale();

  /// Reads the configured country or region.
  ///
  /// Supports Android, iOS, macOS, and Windows. The result describes regional
  /// preferences, not physical location, SIM information, or an account's
  /// country. Android ignores app-language overrides; Apple platforms use
  /// the regional preference exposed by Foundation.
  ///
  /// Returns null for unavailable or unrecognized countries, failed lookups,
  /// and unsupported platforms, including Linux and web. Regions covering
  /// multiple countries cannot be returned as a [Country].
  ///
  /// Reads again on each call without requesting permission. No country is
  /// inferred from a language, and no application fallback is applied.
  Future<Country?> getCountry() async {
    try {
      final code = await DeviceLocalePlatform.instance.getCountry();
      return code == null ? null : Country.tryFromIso2(code);
    } on Object {
      return null;
    }
  }
}
