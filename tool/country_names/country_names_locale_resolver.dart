import 'country_names_source.dart';

/// Derives compact country-catalog aliases from CLDR locale metadata.
final class CountryNamesLocaleResolver {
  /// Resolves the catalogs and locale metadata in [source].
  const CountryNamesLocaleResolver(CountryNamesSourceData source) : _source = source;

  final CountryNamesSourceData _source;

  /// Returns actual catalog locales plus aliases that change runtime fallback.
  ///
  /// The consumer must try an exact tag, remove a region when present, and stop
  /// at an unsupported language-script tag before falling back to English.
  /// Default-script aliases make explicit and implicit default scripts agree.
  /// Locale identifiers with an unspecified language retain English fallback.
  Map<String, String> resolvedAliases() {
    final languages = _source.catalogs.keys.map((locale) => locale.split('-').first).toSet();
    final candidates = <String>{
      ..._source.catalogs.keys,
      ..._source.availableLocales,
      ..._source.defaultContent,
      ..._source.parentLocales.keys,
      for (final locale in {..._source.likelySubtags.keys, ..._source.likelySubtags.values})
        if (languages.contains(locale.split('-').first)) locale,
    };

    // Default content supplies candidate identifiers only. CLDR likely subtags
    // and parent metadata determine matching, not the default-content list.
    for (final locale in candidates.toList()) {
      final expanded = _maximize(locale);
      if (expanded == null) continue;
      final (language, script, region) = _parts(expanded);
      candidates.addAll([
        expanded,
        if (script != null) '$language-$script',
        if (region != null) '$language-$region',
      ]);
    }
    final ordered = candidates.toList()
      ..sort((left, right) {
        final depth = left.split('-').length.compareTo(right.split('-').length);
        return depth != 0 ? depth : left.compareTo(right);
      });
    final result = {for (final locale in _source.catalogs.keys) locale: locale};
    for (final locale in ordered) {
      if (result.containsKey(locale)) continue;
      final catalog = _resolve(locale);
      if (_runtimeFallback(locale, result) != catalog) result[locale] = catalog;
    }
    final keys = result.keys.toList()..sort();
    return Map.unmodifiable({for (final key in keys) key: result[key]});
  }

  String _resolve(String locale) {
    if (_source.catalogs.containsKey(locale)) return locale;
    if (locale == 'root') return 'en';
    final explicit = _source.parentLocales[locale];
    if (explicit != null) return _resolve(explicit);
    final expanded = _maximize(locale);
    final (language, requestedScript, requestedRegion) = _parts(locale);
    final (_, likelyScript, likelyRegion) = _parts(expanded ?? locale);
    final script = requestedScript ?? likelyScript;
    final region = requestedRegion ?? likelyRegion;

    if (script != null && region != null) {
      final full = '$language-$script-$region';
      if (_source.catalogs.containsKey(full)) return full;
      final fullParent = _source.parentLocales[full];
      if (fullParent != null) return _resolve(fullParent);
    }
    if (region != null) {
      final regional = '$language-$region';
      final regionalScript = _parts(_maximize(regional) ?? regional).$2;
      if (script == regionalScript) {
        if (_source.catalogs.containsKey(regional)) return regional;
        final regionalParent = _source.parentLocales[regional];
        if (regionalParent != null) return _resolve(regionalParent);
      }
    }
    if (script != null) {
      final scripted = '$language-$script';
      if (_source.catalogs.containsKey(scripted)) return scripted;
      final scriptParent = _source.parentLocales[scripted];
      if (scriptParent != null) return _resolve(scriptParent);
      if (_parts(_maximize(language) ?? language).$2 != script) return 'en';
    }
    if (_source.catalogs.containsKey(language)) return language;
    final languageParent = _source.parentLocales[language];
    return languageParent == null ? 'en' : _resolve(languageParent);
  }

  String? _maximize(String locale) {
    final (language, script, region) = _parts(locale);
    if (language != 'und' && script != null && region != null) return '$language-$script-$region';
    for (final key in [
      if (script != null && region != null) '$language-$script-$region',
      if (script != null) '$language-$script',
      if (region != null) '$language-$region',
      language,
    ]) {
      final expanded = _source.likelySubtags[key];
      if (expanded == null) continue;
      final (inferredLanguage, inferredScript, inferredRegion) = _parts(expanded);
      return [
        if (language == 'und') inferredLanguage else language,
        ?script ?? inferredScript,
        ?region ?? inferredRegion,
      ].join('-');
    }
    return null;
  }

  (String, String?, String?) _parts(String locale) {
    final parts = locale.split('-');
    final language = parts.first;
    var index = 1;
    String? script;
    String? region;
    if (index < parts.length && RegExp(r'^[A-Z][a-z]{3}$').hasMatch(parts[index])) script = parts[index++];
    if (index < parts.length && RegExp(r'^(?:[A-Z]{2}|[0-9]{3})$').hasMatch(parts[index])) region = parts[index];
    return (language, script, region);
  }

  String _runtimeFallback(String locale, Map<String, String> aliases) {
    var current = locale;
    while (true) {
      final catalog = aliases[current];
      if (catalog != null) return catalog;
      final (language, script, region) = _parts(current);
      if (script != null && region == null) return 'en';
      final separator = current.lastIndexOf('-');
      if (separator < 0) return 'en';
      current = current.substring(0, separator);
      if (current == language) return aliases[language] ?? 'en';
    }
  }
}
