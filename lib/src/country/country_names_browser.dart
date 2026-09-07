import 'dart:js_interop';

part 'country_names_display_names.dart';
part 'country_names_display_options.dart';

/// Reads country names supplied by the browser.
abstract final class CountryNamesPlatform {
  /// Returns a translated name, or null when the locale or API is unavailable.
  static String? displayName(String iso2, String localeTag) {
    try {
      if (_locale != localeTag) {
        _locale = localeTag;
        _names = null;
        if (_CountryNamesDisplayNames.supportedLocalesOf([localeTag.toJS].toJS).toDart.isEmpty) return null;
        _names = _CountryNamesDisplayNames(
          [localeTag.toJS].toJS,
          _CountryNamesDisplayOptions(type: 'region', fallback: 'none'),
        );
      }
      return _names?.of(iso2);
    } on Object {
      // Older embedded browsers can lack Intl.DisplayNames or reject a tag.
      return null;
    }
  }

  static String? _locale;
  static _CountryNamesDisplayNames? _names;
}
