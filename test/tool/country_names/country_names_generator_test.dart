import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/country_names/country_names_encoder.dart';
import '../../../tool/country_names/country_names_generator.dart';
import '../../../tool/country_names/country_names_locale_resolver.dart';
import '../../../tool/country_names/country_names_source.dart';

void main() {
  late Directory directory;
  late CountryNamesSourceData source;
  const escapedName =
      r'$5 ${notInterpolation} \ path "quote"'
      '\n中国🙂\u2028\u2029';
  const outputNames = ['country_names.g.dart', 'country_names_english.g.dart'];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('oh_my_flutter_country_generator_');
    Directory('${directory.path}/lib/src/gen').createSync(recursive: true);
    Directory('${directory.path}/lib/src/country').createSync(recursive: true);
    File('${directory.path}/lib/src/country/country.dart').writeAsStringSync("iso2: 'US'\niso2: 'BR'\n");
    source = CountryNamesSourceData(
      catalogs: const {
        'en': {'BR': escapedName, 'US': 'United States'},
        'pt': {'BR': 'Brasil', 'US': 'Estados Unidos'},
      },
      availableLocales: const ['en', 'pt'],
      parentLocales: const {},
      defaultContent: const ['pt-BR'],
      likelySubtags: const {'en': 'en-Latn-US', 'pt': 'pt-Latn-BR'},
    );
  });

  tearDown(() => directory.deleteSync(recursive: true));

  CountryNamesGenerator generator() => CountryNamesGenerator.test(load: (_) async => source);

  Map<String, String> readOutputs() => {
    for (final name in outputNames) name: File('${directory.path}/lib/src/gen/$name').readAsStringSync(),
  };

  void seedOutputs() {
    for (final name in outputNames) {
      File('${directory.path}/lib/src/gen/$name').writeAsStringSync('previous $name');
    }
  }

  Future<Map<String, Object?>> executeOutputs() async {
    final decoderUri = File('lib/src/country/country_names_lzma.dart').absolute.uri;
    final runner = File('${directory.path}/verify.dart')
      ..writeAsStringSync('''
import 'dart:convert';
import 'lib/src/gen/country_names.g.dart';
import 'lib/src/gen/country_names_english.g.dart';
import '$decoderUri';
import 'dart:typed_data';
void main() {
  final bytes = Uint8List(CountryNameData.byteLength);
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = CountryNameData.packed.codeUnitAt(index ~/ 2) >> ((index & 1) * 8);
  }
  print(jsonEncode({
    'codes': CountryNamesEnglish.codes,
    'names': CountryNamesEnglish.names,
    'namesUtf8': utf8.decode(CountryNamesEnglish.namesUtf8.codeUnits),
    'raw': base64Encode(CountryNamesLzma.decode(bytes)),
  }));
}
''');
    final result = await Process.run(
      'dart',
      ['run', runner.path],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) throw StateError('Generated Dart failed: ${result.stderr}');
    final Object? value = jsonDecode(result.stdout as String);
    if (value is! Map<String, Object?>) throw StateError('Generated output returned an unexpected result');
    return value;
  }

  test('when generation succeeds, it should write both generated files', () async {
    await generator().run(directory, check: false);
    expect(
      Directory('${directory.path}/lib/src/gen').listSync().map((file) => file.uri.pathSegments.last),
      unorderedEquals(outputNames),
    );
  });

  test('when generation repeats with identical inputs, it should reproduce both files byte for byte', () async {
    await generator().run(directory, check: false);
    final original = readOutputs();
    await generator().run(directory, check: false);
    expect(readOutputs(), original);
  });

  test('when checking current generated data, it should preserve both existing files', () async {
    await generator().run(directory, check: false);
    final original = readOutputs();
    await generator().run(directory, check: true);
    expect(readOutputs(), original);
  });

  for (final name in outputNames) {
    test('when $name is stale, it should fail the consistency check', () async {
      await generator().run(directory, check: false);
      File('${directory.path}/lib/src/gen/$name').writeAsStringSync('stale');
      await expectLater(
        generator().run(directory, check: true),
        throwsA(isA<StateError>().having((error) => error.message, 'message', contains('$name is stale'))),
      );
    });

    test('when $name is missing, it should fail the consistency check', () async {
      await generator().run(directory, check: false);
      File('${directory.path}/lib/src/gen/$name').deleteSync();
      await expectLater(
        generator().run(directory, check: true),
        throwsA(isA<StateError>().having((error) => error.message, 'message', contains('$name is stale'))),
      );
    });
  }

  test('when source fetching fails, it should preserve both previously generated files', () async {
    seedOutputs();
    final original = readOutputs();
    final failed = CountryNamesGenerator.test(load: (_) async => throw StateError('HTTP 503 for en'));
    try {
      await failed.run(directory, check: false);
    } on Object {
      // Inspect output preservation after the expected failure.
    }
    expect(readOutputs(), original);
  });

  test('when fetching fails during a check, it should propagate the original error', () async {
    final error = StateError('HTTP 503 for en');
    final failed = CountryNamesGenerator.test(load: (_) async => throw error);
    await expectLater(failed.run(directory, check: true), throwsA(same(error)));
  });

  test('when catalog validation fails, it should preserve both previously generated files', () async {
    seedOutputs();
    final original = readOutputs();
    source = CountryNamesSourceData(
      catalogs: const {
        'en': {'BR': 'Brazil'},
      },
      availableLocales: const ['en'],
      parentLocales: const {},
      defaultContent: const ['en-US'],
      likelySubtags: const {'en': 'en-Latn-US'},
    );
    try {
      await generator().run(directory, check: false);
    } on Object {
      // Inspect output preservation after the expected validation failure.
    }
    expect(readOutputs(), original);
  });

  test('when names contain Dart interpolation and Unicode characters, it should generate their exact text', () async {
    await generator().run(directory, check: false);
    final values = await executeOutputs();
    expect(values['names'], '$escapedName\u0000United States');
  });

  test('when native English names use compact bytes, it should preserve their exact Unicode text', () async {
    await generator().run(directory, check: false);
    final values = await executeOutputs();
    expect(values['namesUtf8'], '$escapedName\u0000United States');
  });

  test(
    'when compressed bytes contain arbitrary code units, it should generate an executable lossless string',
    () async {
      await generator().run(directory, check: false);
      final values = await executeOutputs();
      final encoded = const CountryNamesEncoder().encode(
        countryCodes: ['BR', 'US'],
        catalogs: source.catalogs,
        aliases: CountryNamesLocaleResolver(source).resolvedAliases(),
      );
      expect(values['raw'], base64Encode(encoded.rawBytes));
    },
  );
}
