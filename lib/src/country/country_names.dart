import 'dart:convert';

import 'package:meta/meta.dart';

import '../gen/country_names_english.g.dart';
import 'country_names_io.dart' if (dart.library.js_interop) 'country_names_browser.dart';

/// Supplies offline country names with bounded reuse of the selected locale.
final class CountryNames {
  CountryNames._(this._lookup);

  /// Replaces the platform lookup for focused tests.
  @visibleForTesting
  CountryNames.test({required String? Function(String, String) lookup}) : this._(lookup);

  /// Shared lookup used by the country API.
  static final instance = CountryNames._(CountryNamesPlatform.displayName);

  final String? Function(String, String) _lookup;
  final Map<String, String> _names = {};
  String? _locale;

  /// Returns a localized name, using the generated English name if absent.
  String displayName(String iso2, String localeTag) {
    if (_locale != localeTag) {
      _locale = localeTag;
      _names.clear();
    }
    return _names.putIfAbsent(iso2, () => _lookup(iso2, localeTag) ?? _english[iso2]!);
  }

  static final Map<String, String> _english = _englishNames();

  static Map<String, String> _englishNames() {
    // Each compiler removes the unused representation and its decoding code.
    final names =
        (const bool.fromEnvironment('dart.library.js_interop')
                ? CountryNamesEnglish.names
                : utf8.decode(CountryNamesEnglish.namesUtf8.codeUnits))
            .split('\u0000');
    return {
      for (var index = 0; index < names.length; index++)
        CountryNamesEnglish.codes.substring(index * 2, index * 2 + 2): names[index],
    };
  }
}
