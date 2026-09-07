import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/country/country_names.dart';

void main() {
  test('when a platform translation exists, it should use that display name', () {
    final names = CountryNames.test(lookup: (_, _) => 'Brasil');
    expect(names.displayName('BR', 'pt-BR'), 'Brasil');
  });

  test('when the platform lacks a translation, it should use the generated English name', () {
    final names = CountryNames.test(lookup: (_, _) => null);
    expect(names.displayName('BR', 'zz-ZZ'), 'Brazil');
  });

  test('when the English fallback contains Unicode, it should preserve accents and punctuation', () {
    final names = CountryNames.test(lookup: (_, _) => null);
    expect(names.displayName('CI', 'zz-ZZ'), 'Côte d’Ivoire');
  });

  test('when the platform lacks every translation, it should name every supported country in English', () {
    final names = CountryNames.test(lookup: (_, _) => null);
    expect(
      Country.values.where((country) => names.displayName(country.iso2, 'zz-ZZ').isEmpty),
      isEmpty,
    );
  });

  test('when a country is requested, it should pass its identity and explicit locale to the platform', () {
    (String, String)? request;
    CountryNames.test(
      lookup: (country, locale) {
        request = (country, locale);
        return 'Brasil';
      },
    ).displayName('BR', 'pt-Latn-BR');
    expect(request, ('BR', 'pt-Latn-BR'));
  });

  test('when the same country and locale are requested repeatedly, it should reuse the platform result', () {
    var calls = 0;
    CountryNames.test(
        lookup: (_, _) {
          calls++;
          return 'Brasil';
        },
      )
      ..displayName('BR', 'pt')
      ..displayName('BR', 'pt')
      ..displayName('BR', 'pt');
    expect(calls, 1);
  });

  test('when an English fallback is requested repeatedly, it should reuse the missing platform result', () {
    var calls = 0;
    CountryNames.test(
        lookup: (_, _) {
          calls++;
          return null;
        },
      )
      ..displayName('BR', 'zz')
      ..displayName('BR', 'zz');
    expect(calls, 1);
  });

  test('when another country is requested in the same locale, it should resolve that country separately', () {
    final requests = <String>[];
    CountryNames.test(
        lookup: (country, _) {
          requests.add(country);
          return null;
        },
      )
      ..displayName('BR', 'pt')
      ..displayName('PT', 'pt');
    expect(requests, ['BR', 'PT']);
  });

  test('when the locale changes, it should discard translations retained for the previous locale', () {
    final requests = <String>[];
    CountryNames.test(
        lookup: (_, locale) {
          requests.add(locale);
          return null;
        },
      )
      ..displayName('BR', 'pt')
      ..displayName('BR', 'en')
      ..displayName('BR', 'pt');
    expect(requests, ['pt', 'en', 'pt']);
  });

  test('when the locale region changes, it should request the newly selected regional translation', () {
    final requests = <String>[];
    CountryNames.test(
        lookup: (_, locale) {
          requests.add(locale);
          return null;
        },
      )
      ..displayName('BR', 'pt-BR')
      ..displayName('BR', 'pt-PT');
    expect(requests, ['pt-BR', 'pt-PT']);
  });

  test('when a platform lookup throws, it should preserve the failure', () {
    final names = CountryNames.test(lookup: (_, _) => throw StateError('lookup failed'));
    expect(() => names.displayName('BR', 'pt'), throwsStateError);
  });
}
