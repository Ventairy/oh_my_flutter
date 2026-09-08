import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/country_names/country_names_source.dart';

void main() {
  late HttpServer server;
  late Uri base;
  late Map<String, Object?> documents;
  late List<String> requests;
  late List<String?> authorizationHeaders;
  late Future<void> Function(HttpRequest request)? intercept;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://${server.address.address}:${server.port}/');
    requests = [];
    authorizationHeaders = [];
    intercept = null;
    documents = {
      '/cldr-core/availableLocales.json': {
        'availableLocales': {
          'full': ['en', 'pt', 'pt-PT', 'pt-AO', 'zh', 'zh-Hant'],
        },
      },
      '/cldr-core/defaultContent.json': {
        'defaultContent': ['pt-BR', 'zh-Hant-TW'],
      },
      '/cldr-core/supplemental/likelySubtags.json': {
        'supplemental': {
          'likelySubtags': {'pt': 'pt-Latn-BR', 'zh-TW': 'zh-Hant-TW'},
        },
      },
      '/cldr-core/supplemental/parentLocales.json': {
        'supplemental': {
          'parentLocales': {
            'parentLocale': {'pt-AO': 'pt-PT', 'zh-Hant': 'und'},
          },
        },
      },
      '/tree': {
        'truncated': false,
        'tree': [
          for (final locale in ['en', 'pt', 'pt-PT', 'pt-AO', 'zh', 'zh-Hant'])
            {'path': 'cldr-json/cldr-localenames-full/main/$locale/territories.json', 'type': 'blob'},
        ],
      },
      for (final entry in {
        'en': {'BR': 'Brazil', 'US': 'United States', '001': 'World', 'US-alt-short': 'US'},
        'pt': {'BR': 'Brasil', 'US': 'Estados Unidos'},
        'pt-PT': {'US': 'Estados Unidos da América'},
        'pt-AO': <String, String>{},
        'zh': {'BR': '巴西', 'US': '美国'},
        'zh-Hant': {'BR': '巴西'},
      }.entries)
        '/cldr-localenames-full/main/${entry.key}/territories.json': {
          'main': {
            entry.key: {
              'localeDisplayNames': {'territories': entry.value},
            },
          },
        },
    };
    server.listen((request) async {
      requests.add(request.uri.path);
      authorizationHeaders.add(request.headers.value(HttpHeaders.authorizationHeader));
      if (intercept case final handler?) {
        await handler(request);
        return;
      }
      final data = documents[request.uri.path];
      if (data == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.write(jsonEncode(data));
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  CountryNamesSource source({Duration timeout = const Duration(seconds: 2), int concurrency = 3, String? githubToken}) {
    return CountryNamesSource.test(
      client: HttpClient(),
      repositoryBase: base,
      treeUri: base.resolve('tree'),
      githubToken: githubToken,
      requestTimeout: timeout,
      maxConcurrentFetches: concurrency,
    );
  }

  test('when a GitHub token is available, it should authenticate only the release tree request', () async {
    await source(githubToken: 'test-token').load(['BR', 'US']);
    expect(
      [
        for (var index = 0; index < requests.length; index++)
          if (authorizationHeaders[index] != null) (requests[index], authorizationHeaders[index]),
      ],
      [('/tree', 'Bearer test-token')],
    );
  });

  test('when catalogs inherit regional names, it should resolve explicit parent overrides', () async {
    expect((await source().load(['BR', 'US'])).catalogs['pt-AO'], {
      'BR': 'Brasil',
      'US': 'Estados Unidos da América',
    });
  });

  test('when a script has root as its parent, it should not inherit another script', () async {
    expect((await source().load(['BR', 'US'])).catalogs['zh-Hant'], {'BR': '巴西'});
  });

  test('when territory data includes other regions and alternates, it should retain only country codes', () async {
    expect((await source().load(['BR', 'US'])).catalogs['en']!.keys, ['BR', 'US']);
  });

  test('when metadata contains default content, it should return its automatically discovered locales', () async {
    expect((await source().load(['BR', 'US'])).defaultContent, ['pt-BR', 'zh-Hant-TW']);
  });

  test('when likely subtags identify scripts, it should return source mappings for compact alias generation', () async {
    expect((await source().load(['BR', 'US'])).likelySubtags['zh-TW'], 'zh-Hant-TW');
  });

  test('when an absent intermediate locale has no expected catalog, it should inherit its grandparent', () async {
    documents['/cldr-core/supplemental/parentLocales.json'] = {
      'supplemental': {
        'parentLocales': {
          'parentLocale': {'pt-AO': 'pt-Latn-AO'},
        },
      },
    };
    expect((await source().load(['BR', 'US'])).catalogs['pt-AO'], {
      'BR': 'Brasil',
      'US': 'Estados Unidos',
    });
  });

  test('when a listed language has no territory file, it should not attempt an invented URL', () async {
    documents['/cldr-core/availableLocales.json'] = {
      'availableLocales': {
        'full': ['en', 'pt', 'pt-PT', 'pt-AO', 'zh', 'zh-Hant', 'aa'],
      },
    };
    await source().load(['BR', 'US']);
    expect(requests, isNot(contains('/cldr-localenames-full/main/aa/territories.json')));
  });

  test('when a territory fetch fails, it should report its locale, URL, and HTTP status', () async {
    documents.remove('/cldr-localenames-full/main/pt/territories.json');
    await expectLater(
      source().load(['BR', 'US']),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('pt'),
            contains('${base}cldr-localenames-full/main/pt/territories.json'),
            contains('HTTP 404'),
          ),
        ),
      ),
    );
  });

  test('when metadata is malformed JSON, it should fail with the URL and parsing cause', () async {
    intercept = (request) async {
      request.response.write('{');
      await request.response.close();
    };
    await expectLater(
      source().load(['BR', 'US']),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains(base.toString()), contains('FormatException')),
        ),
      ),
    );
  });

  test('when a body stalls after headers, it should time out instead of waiting indefinitely', () async {
    intercept = (request) async {
      request.response.write('{');
      await request.response.flush();
    };
    await expectLater(
      source(timeout: const Duration(milliseconds: 100)).load(['BR', 'US']),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('TimeoutException'))),
    );
  });

  test('when metadata fails, it should stop scheduling requests immediately', () async {
    documents.remove('/cldr-core/availableLocales.json');
    try {
      await source(concurrency: 1).load(['BR', 'US']);
    } on Object {
      // Inspect cancellation after observing the fatal failure.
    }
    expect(requests, ['/cldr-core/availableLocales.json']);
  });

  test('when a metadata schema is invalid, it should stop scheduling requests immediately', () async {
    documents['/cldr-core/availableLocales.json'] = <String, Object?>{};
    try {
      await source(concurrency: 1).load(['BR', 'US']);
    } on Object {
      // Inspect cancellation after observing the schema failure.
    }
    expect(requests, ['/cldr-core/availableLocales.json']);
  });

  test('when English is missing a country, it should fail with its locale and URL', () async {
    await expectLater(
      source().load(['BR', 'US', 'AC']),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('en'), contains('${base}cldr-localenames-full/main/en/territories.json'), contains('AC')),
        ),
      ),
    );
  });

  test('when parent metadata contains a cycle, it should fail before downloading catalogs', () async {
    documents['/cldr-core/supplemental/parentLocales.json'] = {
      'supplemental': {
        'parentLocales': {
          'parentLocale': {'pt': 'pt-PT', 'pt-PT': 'pt'},
        },
      },
    };
    await expectLater(
      source().load(['BR', 'US']),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('cycle'))),
    );
  });

  for (final fixture in <(String, String, Object?)>[
    (
      'the full locale list is missing',
      '/cldr-core/availableLocales.json',
      {'availableLocales': <String, Object?>{}},
    ),
    (
      'locale identifiers are duplicated',
      '/cldr-core/availableLocales.json',
      {
        'availableLocales': {
          'full': ['en', 'en'],
        },
      },
    ),
    (
      'a locale identifier is invalid',
      '/cldr-core/availableLocales.json',
      {
        'availableLocales': {
          'full': ['en', '../pt'],
        },
      },
    ),
    (
      'a locale identifier is not a string',
      '/cldr-core/availableLocales.json',
      {
        'availableLocales': {
          'full': ['en', 3],
        },
      },
    ),
    (
      'parent metadata has an invalid target',
      '/cldr-core/supplemental/parentLocales.json',
      {
        'supplemental': {
          'parentLocales': {
            'parentLocale': {'pt': 3},
          },
        },
      },
    ),
    (
      'default-content metadata is missing',
      '/cldr-core/defaultContent.json',
      <String, Object?>{},
    ),
    (
      'likely-subtag metadata is malformed',
      '/cldr-core/supplemental/likelySubtags.json',
      {
        'supplemental': {
          'likelySubtags': {'zh-TW': false},
        },
      },
    ),
    (
      'the release tree is truncated',
      '/tree',
      {'truncated': true, 'tree': <Object?>[]},
    ),
    (
      'the release tree contains duplicate catalog files',
      '/tree',
      {
        'truncated': false,
        'tree': [
          for (var index = 0; index < 2; index++)
            {'path': 'cldr-json/cldr-localenames-full/main/en/territories.json', 'type': 'blob'},
        ],
      },
    ),
    (
      'a catalog omits its locale data',
      '/cldr-localenames-full/main/en/territories.json',
      {'main': <String, Object?>{}},
    ),
    (
      'a catalog contains a non-string name',
      '/cldr-localenames-full/main/en/territories.json',
      {
        'main': {
          'en': {
            'localeDisplayNames': {
              'territories': {'BR': 42},
            },
          },
        },
      },
    ),
    (
      'a catalog contains a null-delimited name',
      '/cldr-localenames-full/main/en/territories.json',
      {
        'main': {
          'en': {
            'localeDisplayNames': {
              'territories': {'BR': 'Bra\u0000zil', 'US': 'United States'},
            },
          },
        },
      },
    ),
  ]) {
    test('when ${fixture.$1}, it should throw with the source URL', () async {
      documents[fixture.$2] = fixture.$3;
      await expectLater(
        source().load(['BR', 'US']),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(base.resolve(fixture.$2).toString()),
          ),
        ),
      );
    });
  }

  test('when the source is unavailable, it should fail with the source URL', () async {
    await server.close(force: true);
    await expectLater(
      source().load(['BR', 'US']),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(base.toString()),
        ),
      ),
    );
  });
}
