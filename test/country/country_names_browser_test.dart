@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/country/country_names_browser.dart';

void main() {
  for (final (country, locale, expected) in [
    ('BR', 'pt-BR', 'Brasil'),
    ('CN', 'zh-TW', '中國'),
    ('CN', 'zh-CN', '中国'),
    ('BR', 'sr-Latn-RS', 'Brazil'),
    ('BR', 'sr-Cyrl-RS', 'Бразил'),
    ('AC', 'en', 'Ascension Island'),
    ('TA', 'en', 'Tristan da Cunha'),
    ('XK', 'en', 'Kosovo'),
    ('BR', 'xx', null),
    ('BR', 'invalid tag', null),
  ]) {
    test('when reading $country in $locale, it should select a matching browser translation', () {
      expect(CountryNamesPlatform.displayName(country, locale), expected);
    });
  }
  test('when reading the same locale repeatedly, it should preserve the translation', () {
    CountryNamesPlatform.displayName('BR', 'pt');
    expect(CountryNamesPlatform.displayName('PT', 'pt'), 'Portugal');
  });
}
