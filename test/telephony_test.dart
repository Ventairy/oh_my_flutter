import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('Telephony', () {
    late Uri capturedUri;
    late Future<bool> Function(Uri) fakeLauncher;
    late Telephony telephony;

    setUp(() {
      capturedUri = Uri.parse('about:blank');
      fakeLauncher = (uri) async {
        capturedUri = uri;
        return true;
      };
      telephony = Telephony.test(launcher: fakeLauncher);
    });

    group('when sanitizing the phone number', () {
      test(
        'when launching with a clean international number including +, '
        'it should call the launcher with tel:+<digits>',
        () async {
          await telephony.call(number: '+551198887777');

          expect(
            capturedUri.toString(),
            'tel:+551198887777',
          );
        },
      );

      test(
        'when the number has spaces, dashes, and parens, '
        'it should strip them and keep the leading +',
        () async {
          await telephony.call(number: '+55 (11) 9888-7777');

          expect(
            capturedUri.toString(),
            'tel:+551198887777',
          );
        },
      );

      test(
        'when the number has a leading plus, '
        'it should preserve the plus',
        () async {
          await telephony.call(number: '+551198887777');

          expect(
            capturedUri.toString(),
            'tel:+551198887777',
          );
        },
      );

      test(
        'when the number uses dots as separators, '
        'it should strip dots and keep the plus',
        () async {
          await telephony.call(number: '+55.11.96923.0546');

          expect(
            capturedUri.toString(),
            'tel:+5511969230546',
          );
        },
      );

      test(
        'when the number uses mixed dashes and parens, '
        'it should strip all formatting and keep the plus',
        () async {
          await telephony.call(number: '+55-11-96923-0546');

          expect(
            capturedUri.toString(),
            'tel:+5511969230546',
          );
        },
      );

      test(
        'when the input is "+55 (11) 96923-0546", '
        'it should produce tel:+5511969230546',
        () async {
          await telephony.call(number: '+55 (11) 96923-0546');

          expect(
            capturedUri.toString(),
            'tel:+5511969230546',
          );
        },
      );

      test(
        'when the input is "5511969230546" (no plus), '
        'it should produce tel:5511969230546 without injecting a +',
        () async {
          await telephony.call(number: '5511969230546');

          expect(
            capturedUri.toString(),
            'tel:5511969230546',
          );
        },
      );

      test(
        'when the number is a US format with country code, '
        'it should strip the formatting and keep the plus',
        () async {
          await telephony.call(number: '+1 (415) 555-2671');

          expect(
            capturedUri.toString(),
            'tel:+14155552671',
          );
        },
      );

      test(
        'when the number has leading and trailing whitespace, '
        'it should trim and keep the plus',
        () async {
          await telephony.call(number: '  +55 11 9888 7777  ');

          expect(
            capturedUri.toString(),
            'tel:+551198887777',
          );
        },
      );

      test(
        'when a + appears mid-number (malformed), '
        'it should strip the stray plus and keep only digits',
        () async {
          await telephony.call(number: '55+11 9888');

          expect(
            capturedUri.toString(),
            'tel:55119888',
          );
        },
      );
    });

    group('when validating the number', () {
      test(
        'when the number is an empty string, '
        'it should throw an ArgumentError',
        () async {
          expect(
            () => telephony.call(number: ''),
            throwsArgumentError,
          );
        },
      );

      test(
        'when the number contains only non-digit characters, '
        'it should throw an ArgumentError',
        () async {
          expect(
            () => telephony.call(number: '+-- () '),
            throwsArgumentError,
          );
        },
      );
    });

    group('when reporting the launch result', () {
      test(
        'when the launcher returns true, '
        'it should return true',
        () async {
          final result = await telephony.call(number: '+551198887777');

          expect(result, isTrue);
        },
      );

      test(
        'when the launcher returns false, '
        'it should return false',
        () async {
          telephony = Telephony.test(launcher: (_) async => false);

          final result = await telephony.call(number: '+551198887777');

          expect(result, isFalse);
        },
      );
    });
  });
}
