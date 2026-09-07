import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lzma/lzma.dart';

import '../../../tool/country_names/country_names_encoder.dart';

void main() {
  const encoder = CountryNamesEncoder();
  const catalogs = {
    'en': {'BR': 'Brazil', 'TW': 'Taiwan'},
    'pt': {'BR': 'Brasil', 'TW': 'Taiwan'},
    'pt-BR': {'BR': 'Brasil', 'TW': 'Taiwan'},
    'zh-Hant': {'BR': '巴西', 'TW': '台灣'},
    'und': <String, String>{},
  };

  CountryNamesEncodedData encode({
    List<String> countries = const ['TW', 'BR'],
    Map<String, Map<String, String>> names = catalogs,
    Map<String, String> aliases = const {'zh-TW': 'zh-Hant'},
    Map<String, String> parents = const {'pt-PT': 'pt', 'zh-Hant': 'root'},
  }) => encoder.encode(countryCodes: countries, catalogs: names, aliases: aliases, parentLocales: parents);

  // Independently reads the wire format, including empty cells and aliases.
  Map<String, Object> readPayload(List<int> bytes) {
    var offset = 4;
    int readUnsigned() {
      var value = 0;
      var shift = 0;
      while (true) {
        final byte = bytes[offset++];
        value |= (byte & 127) << shift;
        if (byte < 128) return value;
        shift += 7;
      }
    }

    String readAscii(int length) {
      final value = ascii.decode(bytes.sublist(offset, offset + length));
      offset += length;
      return value;
    }

    final countries = List.generate(readUnsigned(), (_) => readAscii(2));
    final catalogCount = readUnsigned();
    final localeCount = readUnsigned();
    final locales = <(String, int, int)>[];
    var previous = '';
    for (var index = 0; index < localeCount; index++) {
      final prefix = readUnsigned();
      final suffix = readAscii(readUnsigned());
      final locale = previous.substring(0, prefix) + suffix;
      locales.add((locale, readUnsigned(), readUnsigned()));
      previous = locale;
    }
    final grids = <Map<String, String>>[];
    for (var index = 0; index < catalogCount; index++) {
      final names = <String, String>{};
      for (final country in countries) {
        final start = offset;
        while (bytes[offset] != 0) {
          offset++;
        }
        if (offset > start) names[country] = utf8.decode(bytes.sublist(start, offset));
        offset++;
      }
      grids.add(names);
    }
    return {
      'magic': bytes.take(4).toList(),
      'countries': countries,
      'catalogs': {
        for (final locale in locales)
          if (locale.$2 > 0) locale.$1: grids[locale.$2 - 1],
      },
      'parents': {
        for (final locale in locales)
          if (locale.$3 > 0) locale.$1: locales[locale.$3 - 1].$1,
      },
      'consumed': offset,
    };
  }

  test('when names contain different scripts, it should preserve every catalog and alias', () {
    expect(readPayload(encode().rawBytes)['catalogs'], {
      ...catalogs,
      'zh-TW': catalogs['zh-Hant'],
    });
  });

  test('when a catalog has no translations, it should preserve its empty cells', () {
    final decoded = readPayload(encode().rawBytes)['catalogs']! as Map<String, Map<String, String>>;
    expect(decoded['und'], isEmpty);
  });

  test('when locales share a catalog, it should encode the catalog once', () {
    expect(encode().catalogCount, 4);
  });

  test('when input ordering changes, it should produce identical compressed bytes', () {
    expect(
      encode(
        countries: const ['BR', 'TW'],
        names: Map.fromEntries(catalogs.entries.toList().reversed),
        parents: const {'zh-Hant': 'root', 'pt-PT': 'pt'},
      ).compressedBytes,
      encode().compressedBytes,
    );
  });

  test('when parent locales lack their own catalogs, it should retain their relationships', () {
    expect(readPayload(encode().rawBytes)['parents'], {'pt-PT': 'pt', 'zh-Hant': 'root'});
  });

  test('when the compressed payload is decoded, it should restore every original byte', () {
    final data = encode();
    expect(lzma.decode(data.compressedBytes), data.rawBytes);
  });

  test('when the payload header is read, it should identify the version and grid layout', () {
    expect(readPayload(encode().rawBytes)['magic'], [0x43, 0x4e, 1, 0]);
  });

  test('when every grid is read, it should consume the entire payload', () {
    final data = encode();
    expect(readPayload(data.rawBytes)['consumed'], data.rawBytes.length);
  });

  test('when English lacks a country, it should reject the incomplete fallback', () {
    expect(
      () => encode(
        names: const {
          'en': {'BR': 'Brazil'},
        },
        aliases: const {},
      ),
      throwsFormatException,
    );
  });

  test('when a catalog contains an unknown country, it should reject the source data', () {
    expect(
      () => encode(
        names: const {
          'en': {'BR': 'Brazil', 'TW': 'Taiwan', 'ZZ': 'Unknown'},
        },
        aliases: const {},
      ),
      throwsFormatException,
    );
  });

  test('when a name contains a null character, it should reject an ambiguous grid', () {
    expect(
      () => encode(
        names: const {
          'en': {'BR': 'Bra\u0000zil', 'TW': 'Taiwan'},
        },
        aliases: const {},
      ),
      throwsFormatException,
    );
  });

  test('when a name is empty, it should reject an ambiguous missing value', () {
    expect(
      () => encode(
        names: const {
          'en': {'BR': '', 'TW': 'Taiwan'},
        },
        aliases: const {},
      ),
      throwsFormatException,
    );
  });

  test('when an alias target is missing, it should reject a partially supported locale', () {
    expect(() => encode(aliases: const {'es-MX': 'es'}), throwsFormatException);
  });

  test('when aliases form a cycle, it should reject the invalid metadata', () {
    expect(() => encode(aliases: const {'es-MX': 'es', 'es': 'es-MX'}), throwsFormatException);
  });

  test('when aliases name their own catalogs, it should retain those valid identities', () {
    expect(readPayload(encode(aliases: const {'en': 'en'}).rawBytes)['catalogs'], catalogs);
  });

  test('when parents form a cycle, it should reject the invalid metadata', () {
    expect(() => encode(parents: const {'pt-PT': 'pt', 'pt': 'pt-PT'}), throwsFormatException);
  });

  test('when country codes repeat, it should reject duplicate grid columns', () {
    expect(() => encode(countries: const ['BR', 'BR']), throwsFormatException);
  });

  test('when locale identifiers contain non-ASCII text, it should reject unsupported metadata', () {
    expect(() => encode(aliases: const {'português': 'pt'}), throwsFormatException);
  });
}
