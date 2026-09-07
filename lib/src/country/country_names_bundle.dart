import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../gen/country_names.g.dart';
import 'country_names_lzma.dart';

/// Reads the compact CLDR fallback used where system translations are absent.
final class CountryNamesBundle {
  CountryNamesBundle._(this._bytes) {
    if (_bytes.length < 4 || _bytes[0] != 67 || _bytes[1] != 78 || _bytes[2] != 1 || _bytes[3] != 0) {
      throw const FormatException('Unsupported country-name bundle');
    }
    _position = 4;
    final countryCount = _integer();
    for (var index = 0; index < countryCount; index++) {
      _countries[ascii.decode(_take(2))] = index;
    }
    final catalogCount = _integer();
    final localeCount = _integer();
    var previous = '';
    for (var index = 0; index < localeCount; index++) {
      final prefix = _integer();
      if (prefix > previous.length) throw const FormatException('Invalid country-name locale prefix');
      final locale = previous.substring(0, prefix) + ascii.decode(_take(_integer()));
      final catalog = _integer();
      _integer(); // Catalogs already contain their CLDR parent inheritance.
      if (catalog > catalogCount) throw const FormatException('Invalid country-name catalog index');
      if (catalog != 0) _locales[locale] = catalog - 1;
      previous = locale;
    }
    for (var catalog = 0; catalog < catalogCount; catalog++) {
      _catalogOffsets.add(_position);
      for (var country = 0; country < countryCount; country++) {
        while (_position < _bytes.length && _bytes[_position] != 0) {
          _position++;
        }
        if (_position == _bytes.length) throw const FormatException('Truncated country-name catalog');
        _position++;
      }
    }
    if (_position != _bytes.length) throw const FormatException('Trailing country-name data');
  }

  /// Reads a raw grid for exhaustive generator verification and fixture tests.
  @visibleForTesting
  CountryNamesBundle.test(Uint8List bytes) : this._(bytes);

  /// The lazily decoded bundled catalogs.
  static final instance = CountryNamesBundle._(
    CountryNamesLzma.decode(_unpack(CountryNameData.packed, CountryNameData.byteLength)),
  );

  final Uint8List _bytes;
  final Map<String, int> _countries = {};
  final Map<String, int> _locales = {};
  final List<int> _catalogOffsets = [];
  int _position = 0;
  int? _selectedCatalog;
  late List<String> _selectedNames;

  /// Returns a matching translation without falling back across scripts.
  String? displayName(String iso2, String localeTag) {
    final country = _countries[iso2];
    if (country == null) return null;
    var candidate = localeTag;
    int? catalog;
    while (true) {
      catalog = _locales[candidate];
      if (catalog != null) break;
      final separator = candidate.lastIndexOf('-');
      if (separator < 0) return null;
      final lastPart = candidate.substring(separator + 1);
      if (lastPart.length == 4) return null;
      candidate = candidate.substring(0, separator);
    }
    if (_selectedCatalog != catalog) {
      final start = _catalogOffsets[catalog];
      final end = catalog + 1 == _catalogOffsets.length ? _bytes.length : _catalogOffsets[catalog + 1];
      _selectedNames = utf8.decode(Uint8List.sublistView(_bytes, start, end - 1)).split('\u0000');
      _selectedCatalog = catalog;
    }
    final name = _selectedNames[country];
    return name.isEmpty ? null : name;
  }

  /// Locale identifiers retained in the generated lookup.
  @visibleForTesting
  Iterable<String> get locales => _locales.keys;

  /// Country identifiers retained in every catalog row.
  @visibleForTesting
  Iterable<String> get countries => _countries.keys;

  int _integer() {
    var value = 0;
    var shift = 0;
    while (_position < _bytes.length && shift <= 28) {
      final byte = _bytes[_position++];
      value |= (byte & 127) << shift;
      if (byte < 128) return value;
      shift += 7;
    }
    throw const FormatException('Invalid country-name integer');
  }

  Uint8List _take(int length) {
    if (_position + length > _bytes.length) throw const FormatException('Truncated country-name metadata');
    final result = Uint8List.sublistView(_bytes, _position, _position + length);
    _position += length;
    return result;
  }

  static Uint8List _unpack(String value, int length) {
    final bytes = Uint8List(length);
    for (var index = 0; index < length; index++) {
      bytes[index] = value.codeUnitAt(index ~/ 2) >> ((index & 1) * 8);
    }
    return bytes;
  }
}
