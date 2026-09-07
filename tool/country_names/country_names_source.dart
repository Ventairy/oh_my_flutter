import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

part 'country_names_source_data.dart';
part 'country_names_source_json.dart';

/// Obtains complete, validated CLDR inputs for country-name generation.
final class CountryNamesSource {
  /// Fetches the pinned CLDR release using an owned HTTP client.
  CountryNamesSource()
    : _client = HttpClient(),
      _repositoryBase = Uri.parse(repositoryUrl),
      _treeUri = Uri.parse(treeUrl),
      _requestTimeout = const Duration(seconds: 30),
      _maxConcurrentFetches = 12;

  /// Fetches fixture sources, taking ownership of the HTTP client.
  @visibleForTesting
  CountryNamesSource.test({
    required this._client,
    required this._repositoryBase,
    required this._treeUri,
    Duration requestTimeout = const Duration(seconds: 30),
    int maxConcurrentFetches = 12,
  }) : assert(maxConcurrentFetches > 0, 'Concurrency must be positive'),
       assert(requestTimeout > Duration.zero, 'Request timeout must be positive'),
       _requestTimeout = requestTimeout,
       _maxConcurrentFetches = maxConcurrentFetches;

  /// CLDR release used by the bundled data.
  static const version = '48.0.0';

  /// Base URL for the pinned, unmodified source documents.
  static const repositoryUrl = 'https://raw.githubusercontent.com/unicode-org/cldr-json/$version/cldr-json/';

  /// Pinned release inventory used to discover actual territory catalogs.
  static const treeUrl = 'https://api.github.com/repos/unicode-org/cldr-json/git/trees/$version?recursive=1';

  static const _territoryPrefix = 'cldr-json/cldr-localenames-full/main/';
  static const _territorySuffix = '/territories.json';

  final HttpClient _client;
  final Uri _repositoryBase;
  final Uri _treeUri;
  final Duration _requestTimeout;
  final int _maxConcurrentFetches;
  bool _cancelled = false;
  bool _started = false;
  (Object, StackTrace)? _failure;

  /// Downloads every expected catalog and closes the client on completion.
  ///
  /// Any request, JSON, or validation failure aborts the entire operation.
  /// Catalogs contain only [countryCodes]. Locale metadata is kept complete so
  /// the generator can derive compact lookup aliases without manual lists.
  Future<CountryNamesSourceData> load(List<String> countryCodes) async {
    if (_started) throw StateError('A CLDR source can only be loaded once');
    _started = true;
    try {
      if (countryCodes.isEmpty ||
          countryCodes.toSet().length != countryCodes.length ||
          countryCodes.any((code) => !RegExp(r'^[A-Z]{2}$').hasMatch(code))) {
        throw const FormatException('Country codes must be distinct ISO-2 identifiers');
      }
      final metadata = await _concurrent(
        <(String, Uri, void Function(_CountryNamesSourceJson))>[
          (
            'available locale metadata',
            _repositoryBase.resolve('cldr-core/availableLocales.json'),
            (document) => document.localeList(['availableLocales', 'full']),
          ),
          (
            'parent locale metadata',
            _repositoryBase.resolve('cldr-core/supplemental/parentLocales.json'),
            (document) => document.localeMap(['supplemental', 'parentLocales', 'parentLocale']),
          ),
          (
            'default content metadata',
            _repositoryBase.resolve('cldr-core/defaultContent.json'),
            (document) => document.localeList(['defaultContent']),
          ),
          (
            'likely subtag metadata',
            _repositoryBase.resolve('cldr-core/supplemental/likelySubtags.json'),
            (document) => document.localeMap(['supplemental', 'likelySubtags']),
          ),
          (
            'CLDR release tree',
            _treeUri,
            (document) {
              document.list(['tree']);
              if (document.value['truncated'] != false) {
                throw document.failure('release tree must explicitly be complete (truncated: false)');
              }
            },
          ),
        ],
        (entry) async {
          final document = await _fetch(entry.$1, entry.$2);
          entry.$3(document);
          return document;
        },
      );

      final available = metadata[0].localeList(['availableLocales', 'full']);
      final availableSet = available.toSet();
      final parents = metadata[1].localeMap(['supplemental', 'parentLocales', 'parentLocale'])
        ..updateAll((key, value) => value == 'und' ? 'root' : value);
      final defaultContent = metadata[2].localeList(['defaultContent']);
      final likelySubtags = metadata[3].localeMap(['supplemental', 'likelySubtags']);
      final treeDocument = metadata[4];
      final tree = treeDocument.list(['tree']);
      final territoryUris = <String, Uri>{};
      for (final value in tree) {
        if (value is! Map<String, Object?> || value['path'] is! String || value['type'] is! String) {
          throw treeDocument.failure('release tree contains an invalid path or entry type');
        }
        final path = value['path']! as String;
        if (!path.startsWith(_territoryPrefix) || !path.endsWith(_territorySuffix)) continue;
        final locale = path.substring(_territoryPrefix.length, path.length - _territorySuffix.length);
        if (!treeDocument.validLocale(locale) || !availableSet.contains(locale)) {
          throw treeDocument.failure('territory locale "$locale" is invalid or absent from available locales');
        }
        if (value['type'] != 'blob') throw treeDocument.failure('territory locale "$locale" is not a file');
        if (territoryUris.containsKey(locale)) throw treeDocument.failure('duplicate territory locale "$locale"');
        territoryUris[locale] = _repositoryBase.resolve(path.substring('cldr-json/'.length));
      }
      if (!territoryUris.containsKey('en')) throw treeDocument.failure('English territory catalog en is missing');
      final locales = territoryUris.keys.toList()..sort();
      for (final locale in {...available, ...parents.keys, ...parents.values, ...defaultContent}) {
        _validateParents(locale, parents, metadata[1]);
      }

      final raw = await _concurrent(locales, (locale) async {
        final document = await _fetch(locale, territoryUris[locale]!);
        final names = document.object(['main', locale, 'localeDisplayNames', 'territories']);
        final selected = <String, String>{};
        for (final entry in names.entries) {
          final value = entry.value;
          if (value is! String || value.isEmpty || value.contains('\u0000')) {
            throw document.failure('territory "${entry.key}" has an invalid name');
          }
          if (countryCodes.contains(entry.key) && value != '↑↑↑') selected[entry.key] = value;
        }
        return MapEntry(locale, selected);
      });
      final rawCatalogs = Map<String, Map<String, String>>.fromEntries(raw);
      final resolved = <String, Map<String, String>>{};
      for (final locale in locales) {
        _resolve(locale, parents: parents, raw: rawCatalogs, resolved: resolved);
      }
      final english = resolved['en']!;
      final missing = countryCodes.where((code) => !english.containsKey(code)).toList();
      if (missing.isNotEmpty) {
        throw StateError(
          'Invalid CLDR en (${territoryUris['en']}): missing English country names: ${missing.join(', ')}',
        );
      }
      return CountryNamesSourceData(
        catalogs: {for (final locale in locales) locale: resolved[locale]!},
        availableLocales: available,
        parentLocales: parents,
        defaultContent: defaultContent,
        likelySubtags: likelySubtags,
      );
    } finally {
      _cancelled = true;
      _client.close(force: true);
    }
  }

  String _parent(String locale, Map<String, String> parents) {
    final explicit = parents[locale];
    if (explicit != null) return explicit;
    final separator = locale.lastIndexOf('-');
    return separator < 0 ? 'root' : locale.substring(0, separator);
  }

  void _validateParents(String locale, Map<String, String> parents, _CountryNamesSourceJson document) {
    final visited = <String>{};
    var current = locale;
    while (current != 'root') {
      if (!visited.add(current)) throw document.failure('parent locale cycle includes "$current"');
      current = _parent(current, parents);
    }
  }

  Map<String, String> _resolve(
    String locale, {
    required Map<String, String> parents,
    required Map<String, Map<String, String>> raw,
    required Map<String, Map<String, String>> resolved,
  }) {
    if (locale == 'root') return const {};
    return resolved.putIfAbsent(
      locale,
      () => {
        ..._resolve(_parent(locale, parents), parents: parents, raw: raw, resolved: resolved),
        ...?raw[locale],
      },
    );
  }

  Future<_CountryNamesSourceJson> _fetch(String label, Uri uri) async {
    try {
      final request = await _client.getUrl(uri).timeout(_requestTimeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'oh_my_flutter-country-names/$version');
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}', uri: uri);
      final body = await response.transform(utf8.decoder).join().timeout(_requestTimeout);
      final Object? value = jsonDecode(body);
      if (value is! Map<String, Object?>) throw const FormatException('expected a JSON object');
      return _CountryNamesSourceJson(label: label, uri: uri, value: value);
    } on Object catch (error) {
      throw StateError('Failed CLDR $label ($uri): $error');
    }
  }

  Future<List<R>> _concurrent<T, R>(List<T> items, Future<R> Function(T) action) async {
    final results = List<R?>.filled(items.length, null);
    var next = 0;
    Future<void> worker() async {
      try {
        while (!_cancelled && next < items.length) {
          final index = next++;
          results[index] = await action(items[index]);
        }
      } on Object catch (error, stack) {
        _failure ??= (error, stack);
        _cancelled = true;
        _client.close(force: true);
        Error.throwWithStackTrace(_failure!.$1, _failure!.$2);
      }
    }

    await Future.wait([
      for (var index = 0; index < _maxConcurrentFetches && index < items.length; index++) worker(),
    ], eagerError: true);
    return results.cast<R>();
  }
}
