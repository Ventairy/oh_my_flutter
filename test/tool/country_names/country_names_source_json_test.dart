import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/country_names/country_names_source.dart';

void main() {
  test('when a source returns a JSON list instead of an object, it should identify the invalid document', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.write('[]');
      await request.response.close();
    });
    final base = Uri.parse('http://${server.address.address}:${server.port}/');
    final source = CountryNamesSource.test(
      client: HttpClient(),
      repositoryBase: base,
      treeUri: base.resolve('tree'),
      maxConcurrentFetches: 1,
    );

    await expectLater(
      source.load(['BR']),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('${base}cldr-core/availableLocales.json'), contains('expected a JSON object')),
        ),
      ),
    );
  });
}
