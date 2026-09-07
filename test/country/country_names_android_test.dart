@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/country/country_names_android.dart';

void main() {
  group('CountryNamesAndroid', () {
    test('when Portuguese is requested, it should return the native translation', () {
      expect(CountryNamesAndroid.displayName('BR', 'pt-BR'), 'Brasil');
    });
    test('when an unknown language is requested, it should decline the native result', () {
      expect(CountryNamesAndroid.displayName('BR', 'zzz'), isNull);
    });
    test('when names are requested repeatedly, it should keep returning the complete string', () {
      expect(List.generate(1000, (_) => CountryNamesAndroid.displayName('BR', 'pt-BR')), everyElement('Brasil'));
    });
  }, skip: !Platform.isAndroid);
}
