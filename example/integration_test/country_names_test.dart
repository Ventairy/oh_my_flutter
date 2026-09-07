import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'when Portuguese is requested, it should localize the country',
    (_) async {
      expect(Country.brazil.displayName(const Locale('pt', 'BR')), 'Brasil');
    },
  );

  testWidgets(
    'when Traditional Chinese is requested, it should preserve the script',
    (_) async {
      expect(
        Country.unitedStates.displayName(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
        '美國',
      );
    },
  );

  testWidgets(
    'when an unknown language is requested, it should use English',
    (_) async {
      expect(Country.brazil.displayName(const Locale('zzz')), 'Brazil');
    },
  );

  testWidgets(
    'when every country is requested, it should provide an English name',
    (_) async {
      expect(
        Country.values.map((country) {
          return country.displayName(const Locale('en'));
        }),
        everyElement(isNotEmpty),
      );
    },
  );

  for (final entry in const {
    'AC': 'Ascension Island',
    'TA': 'Tristan da Cunha',
    'XK': 'Kosovo',
  }.entries) {
    testWidgets(
      'when ${entry.key} is requested, it should name the extended territory',
      (_) async {
        expect(
          Country.fromIso2(entry.key).displayName(const Locale('en')),
          entry.value,
        );
      },
    );
  }

  testWidgets(
    'when isolates request names concurrently, it should localize each result',
    (_) async {
      final names = await Future.wait(
        List.generate(
          4,
          (_) => Isolate.run(
            () => Country.brazil.displayName(const Locale('pt', 'BR')),
          ),
        ),
      );
      expect(names, List.filled(4, 'Brasil'));
    },
    skip: kIsWeb,
  );
}
