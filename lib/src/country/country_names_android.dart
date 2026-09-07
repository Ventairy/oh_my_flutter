import 'package:jni/jni.dart';

import '../gen/country_names_android.g.dart';

/// Uses Android's installed country translations.
abstract final class CountryNamesAndroid {
  /// Returns the localized name, or null when Android lacks its translation.
  static String? displayName(String iso2, String localeTag) {
    return using((arena) {
      final country = iso2.toJString()..releasedBy(arena);
      final locale = localeTag.toJString()..releasedBy(arena);
      final name = CountryNamesBridge.displayName(country, locale);
      if (name == null) return null;
      name.releasedBy(arena);
      return name.toDartString();
    });
  }
}
