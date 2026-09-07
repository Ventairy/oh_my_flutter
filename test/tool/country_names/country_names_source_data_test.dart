import 'package:flutter_test/flutter_test.dart';

import '../../../tool/country_names/country_names_source.dart';

void main() {
  late Map<String, String> english;
  late CountryNamesSourceData data;

  setUp(() {
    english = {'BR': 'Brazil'};
    data = CountryNamesSourceData(
      catalogs: {'en': english},
      availableLocales: ['en'],
      parentLocales: const {},
      defaultContent: ['en-US'],
      likelySubtags: const {'en': 'en-Latn-US'},
    );
  });

  test('when source maps change later, it should preserve the validated catalog', () {
    english['BR'] = 'changed';
    expect(data.catalogs['en']!['BR'], 'Brazil');
  });

  test('when callers try to modify a catalog, it should reject the mutation', () {
    expect(() => data.catalogs['en']!['BR'] = 'changed', throwsUnsupportedError);
  });

  test('when callers try to modify locale metadata, it should reject the mutation', () {
    expect(() => data.availableLocales.add('pt'), throwsUnsupportedError);
  });
}
