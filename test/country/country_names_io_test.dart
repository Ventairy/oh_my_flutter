@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/country/country_names_io.dart';

void main() {
  test('when reading a native-platform translation, it should return the localized country name', () {
    expect(CountryNamesPlatform.displayName('BR', 'pt-BR'), 'Brasil');
  });
  test('when selecting a different language, it should use the new locale', () {
    CountryNamesPlatform.displayName('BR', 'pt-BR');
    expect(CountryNamesPlatform.displayName('BR', 'ja'), 'ブラジル');
  });
}
