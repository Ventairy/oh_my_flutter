import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('PhoneNumber', () {
    group('when constructing a phone number', () {
      test(
        'when the number is formatted, it should accept the value',
        () {
          expect(
            PhoneNumber('+1 (202) 555-0123').toDisplayString(),
            '+1 202-555-0123',
          );
        },
      );

      test(
        'when the number has no formatting, it should accept the value',
        () {
          expect(
            PhoneNumber('12025550123').toDisplayString(),
            '+1 202-555-0123',
          );
        },
      );

      test(
        'when the number is malformed, it should throw a FormatException',
        () {
          expect(
            () => PhoneNumber('not a phone number'),
            throwsFormatException,
          );
        },
      );

      test(
        'when the country calling code is missing, '
        'it should throw a FormatException',
        () {
          expect(
            () => PhoneNumber('11 91234-5678'),
            throwsFormatException,
          );
        },
      );

      test(
        'when the number has an invalid length, '
        'it should throw a FormatException',
        () {
          expect(
            () => PhoneNumber('+55 11 123'),
            throwsFormatException,
          );
        },
      );
    });

    group('when reading the E.164 value', () {
      test(
        'when the input contains formatting, '
        'it should return the canonical value',
        () {
          expect(
            PhoneNumber('+1 (202) 555-0123').e164,
            '+12025550123',
          );
        },
      );
    });

    group('when producing display text', () {
      test(
        'when the country code is included, '
        'it should return an international display value',
        () {
          expect(
            PhoneNumber('+1 202-555-0123').toDisplayString(),
            '+1 202-555-0123',
          );
        },
      );

      test(
        'when the country code is omitted, '
        'it should retain international grouping',
        () {
          expect(
            PhoneNumber('+1 202-555-0123').toDisplayString(
              includeCountryCode: false,
            ),
            '202-555-0123',
          );
        },
      );

      final internationalCases = <String, String>{
        '+55 11 91234 5678': '+55 11 91234-5678',
        '+1 415 555 2671': '+1 415-555-2671',
        '+1 416 555 0123': '+1 416-555-0123',
        '+44 20 7946 0018': '+44 20 7946 0018',
        '+33 6 55 57 05 76': '+33 6 55 57 05 76',
        '+39 02 3661 8300': '+39 02 3661 8300',
        '+54 9 11 2345 6789': '+54 9 11 2345-6789',
        '+7 912 345 67 89': '+7 912 345-67-89',
        '+7 701 123 4567': '+7 701 123 4567',
        '+81 90 1234 5678': '+81 90-1234-5678',
        '+254 712 123456': '+254 712 123456',
      };

      for (final entry in internationalCases.entries) {
        final input = entry.key;
        final expected = entry.value;
        test(
          'when the input is $input, it should return $expected',
          () {
            expect(
              PhoneNumber(input).toDisplayString(),
              expected,
            );
          },
        );
      }
    });

    group('when calling the phone number', () {
      test(
        'when the number contains formatting, '
        'it should launch its canonical international URI',
        () async {
          late Uri launchedUri;
          final phoneNumber = PhoneNumber.test(
            '+1 (202) 555-0123',
            launcher: (uri) async {
              launchedUri = uri;
              return true;
            },
          );

          await phoneNumber.call();

          expect(launchedUri.toString(), 'tel:+12025550123');
        },
      );

      test(
        'when the launcher accepts the URI, it should return true',
        () async {
          final phoneNumber = PhoneNumber.test(
            '+1 202-555-0123',
            launcher: (_) async => true,
          );

          expect(await phoneNumber.call(), isTrue);
        },
      );

      test(
        'when the launcher rejects the URI, it should return false',
        () async {
          final phoneNumber = PhoneNumber.test(
            '+1 202-555-0123',
            launcher: (_) async => false,
          );

          expect(await phoneNumber.call(), isFalse);
        },
      );
    });
  });
}
