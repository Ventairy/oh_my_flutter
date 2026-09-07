import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:phone_numbers_parser/metadata.dart' as parser;

void main() {
  group('Country', () {
    group('ISO reference', () {
      test('when listing countries, it should include every reference code pair', () {
        final reference = {
          for (final line in File('test/fixtures/country_iso_3166_1.csv').readAsLinesSync())
            if (!line.startsWith('#') && line.isNotEmpty) line.split(',')[0]: line.split(',')[1],
        };

        expect(
          {for (final country in Country.values) country.iso2: country.iso3},
          {...reference, 'AC': 'ASC', 'TA': 'TAA', 'XK': 'XKK'},
        );
      });

      test('when listing countries, it should contain 252 supported entries', () {
        expect(Country.values, hasLength(252));
      });

      test('when reading alpha-2 codes, it should have no duplicates', () {
        expect(Country.values.map((country) => country.iso2).toSet(), hasLength(Country.values.length));
      });

      test('when reading alpha-3 codes, it should have no duplicates', () {
        expect(Country.values.map((country) => country.iso3).toSet(), hasLength(Country.values.length));
      });

      test('when reading Brazil alpha-2, it should return BR', () {
        expect(Country.brazil.iso2, 'BR');
      });

      test('when reading Brazil alpha-3, it should return BRA', () {
        expect(Country.brazil.iso3, 'BRA');
      });
    });

    group('displayName', () {
      test('when reading every country in English, it should return a name', () {
        expect(Country.values.map((country) => country.displayName(const Locale('en'))), everyElement(isNotEmpty));
      });

      test('when reading Brazil in Portuguese, it should return the localized name', () {
        expect(Country.brazil.displayName(const Locale('pt')), 'Brasil');
      });

      test('when reading Brazil in Brazilian Portuguese, it should prefer the exact locale', () {
        expect(Country.brazil.displayName(const Locale('pt', 'BR')), 'Brasil');
      });

      test('when reading a locale without a catalog, it should fall back to English', () {
        expect(Country.brazil.displayName(const Locale('xx')), 'Brazil');
      });

      test('when reading a script locale, it should select the requested translation', () {
        expect(Country.brazil.displayName(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')), '巴西');
      });

      test('when reading a regional locale, it should select the requested translation', () {
        expect(Country.brazil.displayName(const Locale('es', '419')), 'Brasil');
      });

      test('when reading extended identifiers, it should return localized names', () {
        expect(
          [
            Country.ascensionIsland.displayName(const Locale('en')),
            Country.tristanDaCunha.displayName(const Locale('en')),
            Country.kosovo.displayName(const Locale('en')),
          ],
          ['Ascension Island', 'Tristan da Cunha', 'Kosovo'],
        );
      });
    });

    for (final (label, lookup, codeOf, brazilCode, invalidCodes) in [
      (
        'fromIso2',
        Country.fromIso2,
        (Country country) => country.iso2,
        'bR',
        ['', ' ', 'B', 'BRA', 'B R', 'B1', 'XX', 'UK', 'DG', 'SU', 'ſg', 'ß', '🇧🇷'],
      ),
      (
        'fromIso3',
        Country.fromIso3,
        (Country country) => country.iso3,
        'bRa',
        ['', ' ', 'BR', 'BRAA', 'B RA', 'BR1', 'ZZZ', 'XKX', 'SUN', 'uſa', 'uß', '🇧🇷'],
      ),
    ]) {
      group(label, () {
        test('when looking up every ISO code, it should return the original country', () {
          expect(Country.values.map((country) => lookup(codeOf(country))), Country.values);
        });

        test('when the code has mixed case and whitespace, it should find Brazil', () {
          expect(lookup(' \t$brazilCode\n '), Country.brazil);
        });

        for (final code in invalidCodes) {
          test('when the code is "$code", it should throw FormatException', () {
            expect(() => lookup(code), throwsFormatException);
          });
        }
      });
    }

    for (final (label, lookup, codeOf, brazilCode, invalidCodes) in [
      (
        'tryFromIso2',
        Country.tryFromIso2,
        (Country country) => country.iso2,
        'bR',
        ['', ' ', 'B', 'BRA', 'B R', 'B1', 'XX', 'UK', 'DG', 'SU', 'ſg', 'ß', '🇧🇷'],
      ),
      (
        'tryFromIso3',
        Country.tryFromIso3,
        (Country country) => country.iso3,
        'bRa',
        ['', ' ', 'BR', 'BRAA', 'B RA', 'BR1', 'ZZZ', 'XKX', 'SUN', 'uſa', 'uß', '🇧🇷'],
      ),
    ]) {
      group(label, () {
        test('when looking up every ISO code, it should return the original country', () {
          expect(Country.values.map((country) => lookup(codeOf(country))), Country.values);
        });

        test('when the code has mixed case and whitespace, it should find Brazil', () {
          expect(lookup(' \t$brazilCode\n '), Country.brazil);
        });

        for (final code in invalidCodes) {
          test('when the code is "$code", it should return null', () {
            expect(lookup(code), isNull);
          });
        }
      });
    }

    group('extended identifiers', () {
      // CLDR release 48 supplementalData.xml, retrieved 2026-09-05:
      // https://github.com/unicode-org/cldr/blob/release-48/common/supplemental/supplementalData.xml
      for (final (country, iso2, iso3) in [
        (Country.ascensionIsland, 'AC', 'ASC'),
        (Country.tristanDaCunha, 'TA', 'TAA'),
        (Country.kosovo, 'XK', 'XKK'),
      ]) {
        test('when reading ${country.name} identifiers, it should return the reference pair', () {
          expect((country.iso2, country.iso3), (iso2, iso3));
        });

        test('when looking up $iso2, it should find ${country.name}', () {
          expect(Country.fromIso2(' ${iso2.toLowerCase()} '), country);
        });

        test('when looking up $iso3, it should find ${country.name}', () {
          expect(Country.tryFromIso3(' ${iso3.toLowerCase()} '), country);
        });
      }
    });

    group('callingCode', () {
      test('when reading primary codes, it should match phone metadata and researched supplements', () {
        final primaryCodes = {
          for (final entry in parser.metadataByIsoCode.entries) entry.key.name: entry.value.countryCode,
          'PN': '64',
          'TF': '262',
          'GS': '500',
          'UM': '1',
        };

        expect(
          {for (final country in Country.values) country.iso2: country.callingCode},
          {for (final country in Country.values) country.iso2: primaryCodes[country.iso2]},
        );
      });

      for (final (country, callingCode) in [
        (Country.pitcairn, '64'),
        (Country.frenchSouthernTerritories, '262'),
        (Country.southGeorgiaAndTheSouthSandwichIslands, '500'),
        (Country.unitedStatesMinorOutlyingIslands, '1'),
      ]) {
        test('when ${country.name} lacks parser metadata, it should return the researched code $callingCode', () {
          expect(country.callingCode, callingCode);
        });
      }

      test('when reading Brazil calling code, it should return 55 without a plus', () {
        expect(Country.brazil.callingCode, '55');
      });

      test('when countries share a numbering plan, it should return the shared code', () {
        expect([Country.unitedStates.callingCode, Country.canada.callingCode], ['1', '1']);
      });

      test('when a territory uses a national area code, it should omit that area code', () {
        expect(Country.puertoRico.callingCode, '1');
      });

      for (final (country, callingCode) in [
        (Country.saintHelena, '290'),
        (Country.ascensionIsland, '247'),
        (Country.tristanDaCunha, '290'),
        (Country.kosovo, '383'),
      ]) {
        test('when reading ${country.name} calling code, it should return $callingCode', () {
          expect(country.callingCode, callingCode);
        });
      }

      test('when a primary mapping is unavailable, it should leave the code null', () {
        expect(
          Country.values.where((country) => country.callingCode == null),
          unorderedEquals([
            Country.antarctica,
            Country.bouvetIsland,
            Country.heardIslandAndMcDonaldIslands,
          ]),
        );
      });

      test('when a primary code is available, it should contain one to three ASCII digits', () {
        expect(
          Country.values.map((country) => country.callingCode).whereType<String>(),
          everyElement(matches(RegExp(r'^[1-9][0-9]{0,2}$'))),
        );
      });
    });
  });
}
