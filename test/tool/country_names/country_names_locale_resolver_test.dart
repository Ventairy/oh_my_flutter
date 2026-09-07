import 'package:flutter_test/flutter_test.dart';

import '../../../tool/country_names/country_names_locale_resolver.dart';
import '../../../tool/country_names/country_names_source.dart';

void main() {
  late CountryNamesSourceData source;
  late Map<String, String> aliases;

  setUp(() {
    source = CountryNamesSourceData(
      catalogs: const {
        'en': {'CN': 'China', 'US': 'United States'},
        'pt': {'CN': 'China', 'US': 'Estados Unidos'},
        'pt-PT': {'CN': 'China', 'US': 'Estados Unidos da América'},
        'zh': {'CN': '中国'},
        'zh-Hant': {'CN': '中國'},
        'sr': {'CN': 'Кина'},
        'sr-Latn': {'CN': 'Kina'},
      },
      availableLocales: const ['en', 'pt', 'pt-PT', 'pt-AO', 'zh', 'zh-Hant', 'sr', 'sr-Latn'],
      parentLocales: const {'pt-AO': 'pt-PT', 'zh-Hant': 'root', 'sr-Latn': 'root', 'pt-Cyrl': 'root'},
      defaultContent: const ['en-US', 'pt-BR', 'zh-Hans-CN', 'zh-Hant-TW', 'sr-Cyrl-RS', 'sr-Latn-RS'],
      likelySubtags: const {
        'en': 'en-Latn-US',
        'pt': 'pt-Latn-BR',
        'zh': 'zh-Hans-CN',
        'zh-Hant': 'zh-Hant-TW',
        'zh-TW': 'zh-Hant-TW',
        'zh-HK': 'zh-Hant-HK',
        'sr': 'sr-Cyrl-RS',
        'sr-ME': 'sr-Latn-ME',
        'und': 'en-Latn-US',
        'und-TW': 'zh-Hant-TW',
        'zz': 'zz-Latn-ZZ',
      },
    );
    aliases = CountryNamesLocaleResolver(source).resolvedAliases();
  });

  String name(String locale, {String country = 'CN'}) {
    var current = locale;
    while (true) {
      final catalog = aliases[current];
      if (catalog != null) return source.catalogs[catalog]![country] ?? source.catalogs['en']![country]!;
      final parts = current.split('-');
      if (parts.length == 1 || (parts.length == 2 && parts[1].length == 4)) {
        return source.catalogs['en']![country]!;
      }
      current = parts.take(parts.length - 1).join('-');
    }
  }

  test('when a region implies traditional Chinese, it should select traditional names', () {
    expect(name('zh-TW'), '中國');
  });

  test('when a default-content locale includes its script, it should inherit that script catalog', () {
    expect(name('zh-Hant-TW'), '中國');
  });

  test('when a default-content locale uses the default region, it should inherit the language catalog', () {
    expect(name('pt-BR', country: 'US'), 'Estados Unidos');
  });

  test('when a locale explicitly requests Latin Serbian, it should preserve its script', () {
    expect(name('sr-Latn-RS'), 'Kina');
  });

  test('when a region has a different likely script, it should infer that script automatically', () {
    expect(name('sr-ME'), 'Kina');
  });

  test('when a full locale includes its default script, it should preserve regional parent overrides', () {
    expect(name('pt-Latn-AO', country: 'US'), 'Estados Unidos da América');
  });

  test('when a locale omits its script, it should preserve regional parent overrides', () {
    expect(name('pt-AO', country: 'US'), 'Estados Unidos da América');
  });

  test('when a locale explicitly requests simplified Chinese in Taiwan, it should preserve simplified names', () {
    expect(name('zh-Hans-TW'), '中国');
  });

  test('when a script is unknown, it should use English instead of a different script', () {
    expect(name('pt-Abcd-BR', country: 'US'), 'United States');
  });

  test('when an explicit script parent is root, it should use English instead of the language catalog', () {
    expect(name('pt-Cyrl-BR', country: 'US'), 'United States');
  });

  test('when a named language is unsupported, it should retain the English fallback', () {
    expect(name('zz-ZZ'), 'China');
  });

  test('when metadata describes an unsupported language, it should omit its unnecessary aliases', () {
    expect(aliases.keys.where((locale) => locale.startsWith('zz')), isEmpty);
  });

  test('when a script is the default, it should add only the alias required by script-safe runtime fallback', () {
    expect(aliases['pt-Latn'], 'pt');
  });

  test('when generic fallback already selects the same catalog, it should omit redundant aliases', () {
    expect(aliases.containsKey('zh-Hant-TW'), isFalse);
  });

  test('when catalogs are directly available, it should keep every original locale discoverable', () {
    expect(aliases.keys, containsAll(source.catalogs.keys));
  });

  test('when aliases are emitted, it should reference only actual catalogs', () {
    expect(aliases.values.every(source.catalogs.containsKey), isTrue);
  });

  test('when a language lacks a catalog but explicitly inherits another, it should retain that parent', () {
    final inherited = CountryNamesSourceData(
      catalogs: const {
        'en': {'CN': 'China'},
        'fr-HT': {'CN': 'Chine'},
      },
      availableLocales: const ['en', 'fr-HT', 'ht'],
      parentLocales: const {'ht': 'fr-HT'},
      defaultContent: const [],
      likelySubtags: const {'en': 'en-Latn-US', 'fr': 'fr-Latn-FR', 'ht': 'ht-Latn-HT'},
    );
    expect(CountryNamesLocaleResolver(inherited).resolvedAliases()['ht'], 'fr-HT');
  });
}
