import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('OmfWhatsapp', () {
    late Uri capturedUri;
    late Future<bool> Function(Uri) fakeLauncher;
    late OmfWhatsapp whatsapp;

    setUp(() {
      capturedUri = Uri.parse('about:blank');
      fakeLauncher = (Uri uri) async {
        capturedUri = uri;
        return true;
      };
      whatsapp = OmfWhatsapp.test(launcher: fakeLauncher);
    });

    group('when sanitizing the phone number', () {
      test(
        'when launching with a clean international number, '
        'it should call the launcher with https://wa.me/<digits>',
        () async {
          await whatsapp.launchChat(number: '551198887777');

          expect(
            capturedUri.toString(),
            'https://wa.me/551198887777',
          );
        },
      );

      test(
        'when the number has spaces, dashes, and parens, '
        'it should strip them and pass digits only',
        () async {
          await whatsapp.launchChat(number: '+55 (11) 9888-7777');

          expect(
            capturedUri.toString(),
            'https://wa.me/551198887777',
          );
        },
      );

      test(
        'when the number has a leading plus, '
        'it should drop the plus and pass digits only',
        () async {
          await whatsapp.launchChat(number: '+551198887777');

          expect(
            capturedUri.toString(),
            'https://wa.me/551198887777',
          );
        },
      );

      test(
        'when the number uses dots as separators, '
        'it should strip dots and pass digits only',
        () async {
          await whatsapp.launchChat(number: '+55.11.96923.0546');

          expect(
            capturedUri.toString(),
            'https://wa.me/5511969230546',
          );
        },
      );

      test(
        'when the number uses mixed dashes and parens, '
        'it should strip all formatting and pass digits only',
        () async {
          await whatsapp.launchChat(number: '+55-11-96923-0546');

          expect(
            capturedUri.toString(),
            'https://wa.me/5511969230546',
          );
        },
      );

      test(
        'when the input is "+55 (11) 96923-0546", '
        'it should produce https://wa.me/5511969230546',
        () async {
          await whatsapp.launchChat(number: '+55 (11) 96923-0546');

          expect(
            capturedUri.toString(),
            'https://wa.me/5511969230546',
          );
        },
      );

      test(
        'when the input is "5511969230546", '
        'it should produce https://wa.me/5511969230546',
        () async {
          await whatsapp.launchChat(number: '5511969230546');

          expect(
            capturedUri.toString(),
            'https://wa.me/5511969230546',
          );
        },
      );

      test(
        'when the number is a US format with country code, '
        'it should strip the formatting and produce the correct URI',
        () async {
          await whatsapp.launchChat(number: '+1 (415) 555-2671');

          expect(
            capturedUri.toString(),
            'https://wa.me/14155552671',
          );
        },
      );

      test(
        'when the number has leading and trailing whitespace, '
        'it should strip spaces and produce the correct URI',
        () async {
          await whatsapp.launchChat(number: '  5511969230546  ');

          expect(
            capturedUri.toString(),
            'https://wa.me/5511969230546',
          );
        },
      );
    });

    group('when handling the message parameter', () {
      test(
        'when a message is provided with a simple value, '
        'it should include a text query parameter',
        () async {
          await whatsapp.launchChat(
            number: '551198887777',
            message: 'Hello',
          );

          expect(
            capturedUri.queryParametersAll['text'],
            equals(['Hello']),
          );
        },
      );

      test(
        'when a message contains spaces and accented characters (Cataquí), '
        'it should percent-encode them correctly',
        () async {
          await whatsapp.launchChat(
            number: '551198887777',
            message: 'Hey, found you on Cataquí',
          );

          expect(
            capturedUri.toString(),
            contains('text=Hey%2C+found+you+on+Cataqu%C3%AD'),
          );
        },
      );

      test(
        'when the message is null, '
        'it should NOT include any text query parameter',
        () async {
          await whatsapp.launchChat(number: '551198887777');

          expect(capturedUri.queryParametersAll, isEmpty);
        },
      );

      test(
        'when the message is an empty string, '
        'it should NOT include any text query parameter',
        () async {
          await whatsapp.launchChat(number: '551198887777', message: '');

          expect(capturedUri.queryParametersAll, isEmpty);
        },
      );
    });

    group('when validating the number', () {
      test(
        'when the number is an empty string, '
        'it should throw an ArgumentError',
        () async {
          expect(
            () => whatsapp.launchChat(number: ''),
            throwsArgumentError,
          );
        },
      );

      test(
        'when the number contains only non-digit characters, '
        'it should throw an ArgumentError',
        () async {
          expect(
            () => whatsapp.launchChat(number: '+-- () '),
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
          final result = await whatsapp.launchChat(number: '551198887777');

          expect(result, isTrue);
        },
      );

      test(
        'when the launcher returns false, '
        'it should return false',
        () async {
          whatsapp = OmfWhatsapp.test(launcher: (_) async => false);

          final result = await whatsapp.launchChat(number: '551198887777');

          expect(result, isFalse);
        },
      );
    });
  });
}
