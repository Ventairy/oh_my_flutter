import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/country/country_names_apple.dart';

void main() {
  group('CountryNamesApple', () {
    for (final (country, locale, expected) in [
      ('BR', 'pt-BR', 'Brasil'),
      ('CN', 'zh-TW', contains('中國')),
      ('CN', 'zh-CN', contains('中国')),
      ('BR', 'sr-Latn-RS', 'Brazil'),
      ('BR', 'sr-Cyrl-RS', 'Бразил'),
      ('AC', 'en', 'Ascension Island'),
      ('TA', 'en', 'Tristan da Cunha'),
      ('XK', 'en', 'Kosovo'),
    ]) {
      test('when reading $country in $locale, it should use the system translation', () {
        expect(CountryNamesApple.displayName(country, locale), expected);
      });
    }
    test('when the locale is unavailable, it should not use the system default', () {
      expect(CountryNamesApple.displayName('BR', 'xx'), anyOf(isNull, 'Brazil'));
    });
    test('when the country is unknown, it should return no name', () {
      expect(CountryNamesApple.displayName('ZZZZ', 'en'), isNull);
    });
  }, skip: !Platform.isMacOS && !Platform.isIOS);
}
