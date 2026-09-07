part of 'country_names_source.dart';

/// Validated CLDR catalogs and metadata used to generate country-name lookups.
final class CountryNamesSourceData {
  /// Keeps an immutable copy of each catalog and its source metadata.
  CountryNamesSourceData({
    required Map<String, Map<String, String>> catalogs,
    required List<String> availableLocales,
    required Map<String, String> parentLocales,
    required List<String> defaultContent,
    required Map<String, String> likelySubtags,
  }) : catalogs = Map.unmodifiable({
         for (final entry in catalogs.entries) entry.key: Map<String, String>.unmodifiable(entry.value),
       }),
       availableLocales = List.unmodifiable(availableLocales),
       parentLocales = Map.unmodifiable(parentLocales),
       defaultContent = List.unmodifiable(defaultContent),
       likelySubtags = Map.unmodifiable(likelySubtags);

  /// Resolved names for each actual territory catalog, keyed by country ISO-2.
  ///
  /// Missing names intentionally remain absent; the generator supplies English
  /// fallback after choosing a locale without mixing unrelated scripts.
  final Map<String, Map<String, String>> catalogs;

  /// Every locale advertised by the pinned CLDR full distribution.
  final List<String> availableLocales;

  /// Explicit CLDR parent overrides, with `und` normalized to `root`.
  final Map<String, String> parentLocales;

  /// Default-content locales omitted from CLDR files because they inherit.
  final List<String> defaultContent;

  /// Source expansion rules for deriving region and script lookup aliases.
  final Map<String, String> likelySubtags;
}
