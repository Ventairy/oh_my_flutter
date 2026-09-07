import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'country_names_encoder.dart';
import 'country_names_locale_resolver.dart';
import 'country_names_source.dart';

/// Updates generated country data only after every source has been validated.
final class CountryNamesGenerator {
  /// Downloads all country-name inputs from the pinned CLDR release.
  CountryNamesGenerator() : _load = _loadSource;

  /// Supplies fixture data and failures without making network requests.
  @visibleForTesting
  CountryNamesGenerator.test({required this._load});

  final Future<CountryNamesSourceData> Function(List<String>) _load;

  /// Generates or checks every output, preserving existing files on fetch errors.
  Future<String> run(Directory root, {required bool check}) async {
    final countries =
        RegExp("iso2: '([A-Z]{2})'")
            .allMatches(File('${root.path}/lib/src/country/country.dart').readAsStringSync())
            .map((match) => match.group(1)!)
            .toList()
          ..sort();
    final source = await _load(countries);
    final encoded = const CountryNamesEncoder().encode(
      countryCodes: countries,
      catalogs: source.catalogs,
      aliases: CountryNamesLocaleResolver(source).resolvedAliases(),
    );
    final outputs = {
      'country_names.g.dart': _bundle(encoded, source.catalogs.length),
      'country_names_english.g.dart': _english(source, countries),
    };
    final directory = Directory('${root.path}/lib/src/gen');
    if (check) {
      for (final entry in outputs.entries) {
        final output = File('${directory.path}/${entry.key}');
        if (!output.existsSync() || output.readAsStringSync() != entry.value) {
          throw StateError('${output.path} is stale; run make generate-country-names');
        }
      }
    } else {
      directory.createSync(recursive: true);
      final temporary = <File>[];
      try {
        for (final entry in outputs.entries) {
          final file = File('${directory.path}/${entry.key}.tmp');
          temporary.add(file);
          file.writeAsStringSync(entry.value, flush: true);
        }
        for (final file in temporary) {
          file.renameSync(file.path.substring(0, file.path.length - 4));
        }
      } finally {
        for (final file in temporary) {
          if (file.existsSync()) file.deleteSync();
        }
      }
    }
    return '${check ? 'Verified' : 'Generated'} ${source.catalogs.length} CLDR catalogs, '
        '${encoded.catalogCount} distinct rows, ${encoded.localeCount} locale lookups, '
        '${countries.length} countries; ${encoded.compressedBytes.length} compressed bytes.';
  }

  static Future<CountryNamesSourceData> _loadSource(List<String> countries) => CountryNamesSource().load(countries);

  static String _bundle(CountryNamesEncodedData encoded, int sourceCount) {
    final output = StringBuffer(_header)
      ..writeln('abstract final class CountryNameData {')
      ..writeln('  static const sourceLocaleCount = $sourceCount;')
      ..writeln('  static const catalogCount = ${encoded.catalogCount};')
      ..writeln('  static const byteLength = ${encoded.compressedBytes.length};')
      ..writeln('  static const packed =');
    final packed = encoded.packedString;
    for (var offset = 0; offset < packed.length; offset += 32) {
      output.write("      '");
      for (var index = offset; index < offset + 32 && index < packed.length; index++) {
        output
          ..write(r'\u')
          ..write(packed.codeUnitAt(index).toRadixString(16).padLeft(4, '0'));
      }
      output.writeln("'${offset + 32 >= packed.length ? ';' : ''}");
    }
    return (output..writeln('}')).toString();
  }

  static String _english(CountryNamesSourceData source, List<String> countries) {
    final output = StringBuffer(_header)
      ..writeln('abstract final class CountryNamesEnglish {')
      ..writeln('  static const codes = ${jsonEncode(countries.join())};');
    // Native snapshots save space with byte strings; web output favors Unicode.
    // The runtime platform constant selects one, pruning the other from builds.
    for (final field in ['names', 'namesUtf8']) {
      output.writeln('  static const $field =');
      for (var index = 0; index < countries.length; index++) {
        final last = index + 1 == countries.length;
        final name = source.catalogs['en']![countries[index]]! + (last ? '' : '\u0000');
        final value = field == 'names' ? name : latin1.decode(utf8.encode(name));
        output.writeln('      ${jsonEncode(value).replaceAll(r'$', r'\$')}${last ? ';' : ''}');
      }
    }
    return (output..writeln('}')).toString();
  }

  static const _header =
      '// GENERATED CODE - DO NOT MODIFY BY HAND.\n'
      '// Unicode CLDR JSON ${CountryNamesSource.version}: ${CountryNamesSource.repositoryUrl}\n'
      '// Unicode-3.0 license: see THIRD_PARTY_NOTICES.md.\n\n';
}
