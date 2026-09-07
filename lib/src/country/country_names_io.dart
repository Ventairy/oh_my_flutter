import 'dart:io';

import 'country_names_android.dart';
import 'country_names_apple.dart';
import 'country_names_bundle.dart';
import 'country_names_windows.dart';

/// Selects the platform's offline source of translated country names.
abstract final class CountryNamesPlatform {
  /// Returns the country name for [localeTag], or null if unavailable.
  static String? displayName(String iso2, String localeTag) {
    if (Platform.isAndroid) return CountryNamesAndroid.displayName(iso2, localeTag);
    if (Platform.isIOS || Platform.isMacOS) return CountryNamesApple.displayName(iso2, localeTag);
    if (Platform.isWindows) return CountryNamesWindows.instance.displayName(iso2, localeTag);
    return CountryNamesBundle.instance.displayName(iso2, localeTag);
  }
}
