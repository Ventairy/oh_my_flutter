import 'dart:convert';
import 'dart:typed_data';

import 'package:lzma/lzma.dart';

part 'country_names_encoded_data.dart';

/// Produces reproducible, compressed country catalogs without reducing coverage.
final class CountryNamesEncoder {
  /// Creates a stateless encoder for validated CLDR country-name inputs.
  const CountryNamesEncoder();

  /// Encodes every catalog, lookup alias, and explicit locale parent.
  ///
  /// Catalogs are deduplicated, then similar catalogs are placed together to
  /// improve compression. Missing names remain absent in the encoded data.
  /// Invalid source data and a failed compression round trip stop generation.
  CountryNamesEncodedData encode({
    required List<String> countryCodes,
    required Map<String, Map<String, String>> catalogs,
    Map<String, String> aliases = const {},
    Map<String, String> parentLocales = const {},
  }) {
    final countries = countryCodes.toList()..sort();
    _validate(countries, catalogs, aliases, parentLocales);

    final catalogLocales = catalogs.keys.toList()..sort();
    final rows = <List<String?>>[];
    final rowByContents = <String, int>{};
    final rowByLocale = <String, int>{};
    for (final locale in catalogLocales) {
      final row = [for (final country in countries) catalogs[locale]![country]];
      final signature = row.map((name) => name ?? '').join('\u0000');
      final rowIndex = rowByContents.putIfAbsent(signature, () {
        rows.add(row);
        return rows.length - 1;
      });
      rowByLocale[locale] = rowIndex;
    }
    for (final alias in aliases.keys) {
      rowByLocale[alias] = rowByLocale[_resolveAlias(alias, aliases, catalogs)]!;
    }

    final order = _catalogOrder(rows, countries.length);
    final orderedIndex = <int, int>{
      for (var index = 0; index < order.length; index++) order[index]: index + 1,
    };
    final locales = {...rowByLocale.keys, ...parentLocales.keys, ...parentLocales.values}.toList()..sort();
    final localeIndex = <String, int>{
      for (var index = 0; index < locales.length; index++) locales[index]: index + 1,
    };

    // CN, version 1, plain catalog grid. Integers are unsigned LEB128.
    final output = BytesBuilder(copy: false)..add(const [0x43, 0x4e, 1, 0]);
    _writeUnsigned(output, countries.length);
    output.add(ascii.encode(countries.join()));
    _writeUnsigned(output, rows.length);
    _writeUnsigned(output, locales.length);
    var previousLocale = '';
    for (final locale in locales) {
      var prefix = 0;
      while (prefix < previousLocale.length &&
          prefix < locale.length &&
          previousLocale.codeUnitAt(prefix) == locale.codeUnitAt(prefix)) {
        prefix++;
      }
      final suffix = ascii.encode(locale.substring(prefix));
      _writeUnsigned(output, prefix);
      _writeUnsigned(output, suffix.length);
      output.add(suffix);
      _writeUnsigned(output, orderedIndex[rowByLocale[locale]] ?? 0);
      _writeUnsigned(output, localeIndex[parentLocales[locale]] ?? 0);
      previousLocale = locale;
    }
    for (final rowIndex in order) {
      for (final name in rows[rowIndex]) {
        if (name != null) output.add(utf8.encode(name));
        output.addByte(0);
      }
    }

    final rawBytes = output.takeBytes();
    final compressedBytes = lzma.encode(rawBytes);
    final decoded = lzma.decode(compressedBytes);
    if (decoded.length != rawBytes.length) {
      throw StateError('Country-name compression changed the payload length');
    }
    for (var index = 0; index < rawBytes.length; index++) {
      if (decoded[index] != rawBytes[index]) {
        throw StateError('Country-name compression changed payload byte $index');
      }
    }
    return CountryNamesEncodedData(
      rawBytes: rawBytes,
      compressedBytes: compressedBytes,
      catalogCount: rows.length,
      localeCount: locales.length,
    );
  }

  static final _countryPattern = RegExp(r'^[A-Z]{2}$');
  static final _localePattern = RegExp(r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{2,8})*$');

  static void _validate(
    List<String> countries,
    Map<String, Map<String, String>> catalogs,
    Map<String, String> aliases,
    Map<String, String> parents,
  ) {
    if (countries.isEmpty ||
        countries.toSet().length != countries.length ||
        countries.any((country) => !_countryPattern.hasMatch(country))) {
      throw const FormatException('Country identifiers must be distinct uppercase ISO-2 codes');
    }
    final knownCountries = countries.toSet();
    for (final entry in catalogs.entries) {
      if (entry.value.keys.any((country) => !knownCountries.contains(country))) {
        throw FormatException('Catalog ${entry.key} contains an unknown country');
      }
      if (entry.value.values.any((name) => name.isEmpty || name.contains('\u0000'))) {
        throw FormatException('Catalog ${entry.key} contains an empty or null-delimited name');
      }
    }
    final english = catalogs['en'];
    if (english == null || countries.any((country) => !english.containsKey(country))) {
      throw const FormatException('The English catalog must name every country');
    }
    for (final locale in {
      ...catalogs.keys,
      ...aliases.keys,
      ...aliases.values,
      ...parents.keys,
      ...parents.values,
    }) {
      if (!_localePattern.hasMatch(locale)) throw FormatException('Invalid locale identifier: $locale');
    }
    for (final alias in aliases.keys) {
      final target = _resolveAlias(alias, aliases, catalogs);
      if (catalogs.containsKey(alias) && alias != target) {
        throw FormatException('Alias $alias would replace an existing catalog');
      }
    }
    for (final locale in parents.keys) {
      final visited = <String>{};
      String? current = locale;
      while (current != null) {
        if (!visited.add(current)) throw FormatException('Locale parent cycle at $current');
        current = parents[current];
      }
    }
  }

  static String _resolveAlias(
    String locale,
    Map<String, String> aliases,
    Map<String, Map<String, String>> catalogs,
  ) {
    final visited = <String>{};
    var current = locale;
    while (true) {
      if (!visited.add(current)) throw FormatException('Locale alias cycle at $current');
      final target = aliases[current];
      if (target == null || target == current) {
        if (!catalogs.containsKey(current)) throw FormatException('Alias $locale has no catalog: $current');
        return current;
      }
      current = target;
    }
  }

  // Prim's minimum spanning tree groups rows with identical country names.
  // The virtual first row is empty, making the order independent of a chosen
  // product language. Stable sorted catalog indexes break equal-cost ties.
  static List<int> _catalogOrder(List<List<String?>> rows, int countryCount) {
    final names = <String, int>{};
    final ids = <List<int>>[
      List<int>.filled(countryCount, 0),
      for (final row in rows)
        [
          for (final name in row)
            if (name == null) 0 else names.putIfAbsent(name, () => names.length + 1),
        ],
    ];
    final selected = List<bool>.filled(ids.length, false);
    final distances = List<int>.filled(ids.length, countryCount + 1)..[0] = 0;
    final parents = List<int>.filled(ids.length, -1);
    for (var step = 0; step < ids.length; step++) {
      var nearest = -1;
      for (var index = 0; index < ids.length; index++) {
        if (!selected[index] && (nearest < 0 || distances[index] < distances[nearest])) nearest = index;
      }
      selected[nearest] = true;
      for (var candidate = 0; candidate < ids.length; candidate++) {
        if (selected[candidate]) continue;
        var distance = 0;
        for (var country = 0; country < countryCount; country++) {
          if (ids[nearest][country] != ids[candidate][country]) distance++;
          if (distance >= distances[candidate]) break;
        }
        if (distance < distances[candidate]) {
          distances[candidate] = distance;
          parents[candidate] = nearest;
        }
      }
    }
    final children = List.generate(ids.length, (_) => <int>[]);
    for (var index = 1; index < ids.length; index++) {
      children[parents[index]].add(index);
    }
    final order = <int>[];
    final pending = <int>[0];
    while (pending.isNotEmpty) {
      final index = pending.removeLast();
      if (index > 0) order.add(index - 1);
      pending.addAll(children[index].reversed);
    }
    return order;
  }

  static void _writeUnsigned(BytesBuilder output, int value) {
    var remaining = value;
    while (remaining >= 128) {
      output.addByte((remaining & 127) | 128);
      remaining >>= 7;
    }
    output.addByte(remaining);
  }
}
