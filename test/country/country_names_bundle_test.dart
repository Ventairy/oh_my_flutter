import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/country/country_names_bundle.dart';

import '../../tool/country_names/country_names_encoder.dart';

void main() {
  const fixtureCatalogs = {
    'en': {'BR': 'Brazil', 'CN': 'China', 'PT': 'Portugal'},
    'pt': {'BR': 'Brasil', 'CN': 'China', 'PT': 'Portugal'},
    'pt-BR': {'BR': 'Brasil', 'CN': 'China', 'PT': 'Portugal'},
    'zh': {'BR': '巴西', 'CN': '中国', 'PT': '葡萄牙'},
    'zh-Hant': {'BR': '巴西', 'CN': '中國'},
    'und': <String, String>{},
  };
  const fixtureAliases = {'pt-Latn': 'pt', 'zh-CN': 'zh', 'zh-Hans': 'zh', 'zh-TW': 'zh-Hant'};
  const validSingleName = [
    67, 78, 1, 0, // CN version 1, grid layout.
    1, 66, 82, // One country: BR.
    1, 1, // One catalog and locale.
    0, 2, 101, 110, 1, 0, // en, first catalog, no parent.
    66, 114, 97, 122, 105, 108, 0, // Brazil.
  ];
  late Uint8List fixtureBytes;
  late CountryNamesBundle bundle;

  setUpAll(() {
    fixtureBytes = const CountryNamesEncoder()
        .encode(
          countryCodes: const ['PT', 'CN', 'BR'],
          catalogs: fixtureCatalogs,
          aliases: fixtureAliases,
          parentLocales: const {'zh-Hant': 'root'},
        )
        .rawBytes;
  });

  setUp(() {
    bundle = CountryNamesBundle.test(fixtureBytes);
  });

  test('when every fixture catalog is read, it should preserve every country name', () {
    expect(
      {
        for (final locale in fixtureCatalogs.keys)
          locale: {
            for (final country in ['BR', 'CN', 'PT']) country: bundle.displayName(country, locale),
          },
      },
      {
        for (final catalog in fixtureCatalogs.entries)
          catalog.key: {
            for (final country in ['BR', 'CN', 'PT']) country: catalog.value[country],
          },
      },
    );
  });

  test('when every fixture alias is read, it should select its generated catalog', () {
    expect(
      {
        for (final alias in fixtureAliases.keys)
          alias: {
            for (final country in ['BR', 'CN', 'PT']) country: bundle.displayName(country, alias),
          },
      },
      {
        for (final alias in fixtureAliases.entries)
          alias.key: {
            for (final country in ['BR', 'CN', 'PT']) country: fixtureCatalogs[alias.value]![country],
          },
      },
    );
  });

  for (final (locale, expected) in [
    ('pt-PT', 'Brasil'),
    ('pt-Latn-AO', 'Brasil'),
    ('zh-Hant-HK', '巴西'),
    ('pt-Cyrl-PT', null),
    ('pt-Cyrl', null),
    ('zz-ZZ', null),
    ('und', null),
  ]) {
    test('when the requested locale is $locale, it should preserve script-safe fallback', () {
      expect(bundle.displayName('BR', locale), expected);
    });
  }

  test('when a requested country is absent, it should return no translation', () {
    expect(bundle.displayName('ZZ', 'pt'), isNull);
  });

  test('when a translated cell is empty, it should leave English fallback to its caller', () {
    expect(bundle.displayName('PT', 'zh-Hant'), isNull);
  });

  test('when the selected catalog changes, it should return the newly selected script', () {
    bundle.displayName('CN', 'zh');
    expect(bundle.displayName('CN', 'zh-Hant'), '中國');
  });

  test('when a previously selected catalog is requested again, it should restore that catalog', () {
    bundle
      ..displayName('CN', 'zh')
      ..displayName('CN', 'zh-Hant');
    expect(bundle.displayName('CN', 'zh'), '中国');
  });

  test('when a duplicate catalog locale is selected, it should preserve all names', () {
    bundle.displayName('BR', 'pt');
    expect(bundle.displayName('BR', 'pt-BR'), 'Brasil');
  });

  test('when country identifiers are inspected, it should report every sorted grid column', () {
    expect(bundle.countries, ['BR', 'CN', 'PT']);
  });

  test('when locale identifiers are inspected, it should include catalogs and aliases', () {
    expect(bundle.locales.toSet(), {...fixtureCatalogs.keys, ...fixtureAliases.keys});
  });

  test('when the independent minimal wire fixture is decoded, it should return its country name', () {
    final minimal = CountryNamesBundle.test(Uint8List.fromList(validSingleName));
    expect(minimal.displayName('BR', 'en'), 'Brazil');
  });

  for (final (description, bytes) in <(String, List<int>)>[
    ('a truncated header', [67, 78, 1]),
    ('an unsupported version', [...validSingleName]..[2] = 2),
    ('an unsupported layout', [...validSingleName]..[3] = 1),
    ('an unterminated integer', [67, 78, 1, 0, 128]),
    ('an overflowing integer', [67, 78, 1, 0, 128, 128, 128, 128, 128, 0]),
    ('truncated country metadata', [67, 78, 1, 0, 1, 66]),
    ('a locale prefix longer than its predecessor', [...validSingleName]..[9] = 1),
    ('a catalog index outside the grid', [...validSingleName]..[13] = 2),
    ('truncated locale metadata', validSingleName.sublist(0, 12)),
    ('a missing catalog terminator', validSingleName.sublist(0, validSingleName.length - 1)),
    ('trailing payload bytes', [...validSingleName, 0]),
  ]) {
    test('when the payload contains $description, it should reject the bundle', () {
      expect(() => CountryNamesBundle.test(Uint8List.fromList(bytes)), throwsFormatException);
    });
  }

  test('when a catalog contains invalid UTF-8, it should reject the affected translation', () {
    final invalidUtf8 = CountryNamesBundle.test(Uint8List.fromList(validSingleName)..[15] = 255);
    expect(() => invalidUtf8.displayName('BR', 'en'), throwsFormatException);
  });
}
