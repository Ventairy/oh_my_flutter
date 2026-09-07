@TestOn('vm')
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/country/country_names_windows.dart';
import 'package:oh_my_flutter/src/gen/country_names_windows.g.dart';

void main() {
  late NativeCallable<Int32 Function(Pointer<Char>, Pointer<Char>, Pointer<Uint16>, Int32, Pointer<Int>)> callback;
  late CountryNamesWindows source;
  var translation = 'Brasil';
  var resultStatus = 0;
  var reportedLength = -1;
  var receivedCountry = '';
  var receivedLocale = '';

  setUp(() {
    translation = 'Brasil';
    resultStatus = 0;
    reportedLength = -1;
    callback =
        NativeCallable<Int32 Function(Pointer<Char>, Pointer<Char>, Pointer<Uint16>, Int32, Pointer<Int>)>.isolateLocal(
          (Pointer<Char> country, Pointer<Char> locale, Pointer<Uint16> output, int capacity, Pointer<Int> status) {
            receivedCountry = country.cast<Utf8>().toDartString();
            receivedLocale = locale.cast<Utf8>().toDartString();
            if (capacity == 0) {
              status.value = UErrorCode.U_BUFFER_OVERFLOW_ERROR.value;
              return translation.length;
            }
            status.value = resultStatus;
            output.asTypedList(translation.length).setAll(0, translation.codeUnits);
            return reportedLength < 0 ? translation.length : reportedLength;
          },
          exceptionalReturn: 0,
        );
    source = CountryNamesWindows.test(
      bindings: CountryNamesWindowsBindings.fromLookup(
        <T extends NativeType>(symbol) => callback.nativeFunction.cast<T>(),
      ),
    );
  });
  tearDown(() => callback.close());

  test('when ICU translates the country, it should return its name synchronously', () {
    expect(source.displayName('BR', 'pt-BR'), 'Brasil');
  });
  test('when ICU requests a region locale, it should receive the country separately from the language', () {
    source.displayName('BR', 'pt-BR');
    expect(receivedCountry, 'und_BR');
  });
  test('when the display locale includes a script, it should preserve its subtags', () {
    source.displayName('BR', 'sr-Latn-RS');
    expect(receivedLocale, 'sr_Latn_RS');
  });
  test('when a translation includes non-BMP characters, it should preserve the UTF-16 pairs', () {
    translation = '𞤁𞤫𞤲𞤼𞤢𞤤 𞤂𞤢𞤪𞤫';
    expect(source.displayName('US', 'ff-Adlm'), translation);
  });
  test('when a translation exceeds a small buffer, it should allocate its full reported length', () {
    translation = List.filled(400, 'é').join();
    expect(source.displayName('BR', 'pt'), translation);
  });
  test('when ICU uses a parent locale, it should retain the translated result', () {
    resultStatus = UErrorCode.U_USING_FALLBACK_WARNING.value;
    expect(source.displayName('BR', 'pt-BR'), 'Brasil');
  });
  test('when ICU substitutes the default language, it should decline that result', () {
    resultStatus = UErrorCode.U_USING_DEFAULT_WARNING.value;
    expect(source.displayName('BR', 'zzz'), isNull);
  });
  test('when ICU reports a failure, it should decline the result', () {
    resultStatus = UErrorCode.U_MISSING_RESOURCE_ERROR.value;
    expect(source.displayName('BR', 'pt'), isNull);
  });
  test('when ICU reports more characters than the buffer holds, it should decline the result', () {
    reportedLength = 1000;
    expect(source.displayName('BR', 'pt'), isNull);
  });
  test('when ICU returns a country code, it should decline the untranslated result', () {
    translation = 'BR';
    expect(source.displayName('BR', 'pt'), isNull);
  });
  test('when ICU returns no characters, it should decline the result', () {
    translation = '';
    expect(source.displayName('BR', 'pt'), isNull);
  });
  test('when Windows lacks ICU, it should retain the bundled translation', () {
    expect(CountryNamesWindows.test(bindings: null).displayName('BR', 'pt-BR'), 'Brasil');
  });
  test('when Windows supplies ICU, it should translate using the installed library', () {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final native = CountryNamesWindows.test(
      bindings: CountryNamesWindowsBindings(
        DynamicLibrary.open(
          '$systemRoot${Platform.pathSeparator}System32${Platform.pathSeparator}icu.dll',
        ),
      ),
    );
    expect(native.displayName('BR', 'pt-BR'), 'Brasil');
  }, skip: !Platform.isWindows);
}
