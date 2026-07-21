import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('Whatsapp', () {
    group('when on web (isWeb: true)', () {
      late List<Uri> capturedUris;
      late Future<bool> Function(Uri) fakeLauncher;
      late Whatsapp whatsapp;

      setUp(() {
        capturedUris = [];
        fakeLauncher = (uri) async {
          capturedUris.add(uri);
          return true;
        };

        whatsapp = Whatsapp.test(launcher: fakeLauncher, isWeb: true);
      });

      group('when sanitizing the phone number', () {
        test('when launching with a clean international number, '
            'it should call the launcher with https://wa.me/<digits>', () async {
          await whatsapp.launchChat(number: '551198887777');

          expect(capturedUris.single.toString(), 'https://wa.me/551198887777');
        });

        test('when the number has spaces, dashes, and parens, '
            'it should strip them and pass digits only', () async {
          await whatsapp.launchChat(number: '+55 (11) 9888-7777');

          expect(capturedUris.single.toString(), 'https://wa.me/551198887777');
        });

        test('when the number has a leading plus, '
            'it should drop the plus and pass digits only', () async {
          await whatsapp.launchChat(number: '+551198887777');

          expect(capturedUris.single.toString(), 'https://wa.me/551198887777');
        });

        test('when the number uses dots as separators, '
            'it should strip dots and pass digits only', () async {
          await whatsapp.launchChat(number: '+55.11.96923.0546');

          expect(capturedUris.single.toString(), 'https://wa.me/5511969230546');
        });

        test('when the number uses mixed dashes and parens, '
            'it should strip all formatting and pass digits only', () async {
          await whatsapp.launchChat(number: '+55-11-96923-0546');

          expect(capturedUris.single.toString(), 'https://wa.me/5511969230546');
        });

        test('when the input is "+55 (11) 96923-0546", '
            'it should produce https://wa.me/5511969230546', () async {
          await whatsapp.launchChat(number: '+55 (11) 96923-0546');

          expect(capturedUris.single.toString(), 'https://wa.me/5511969230546');
        });

        test('when the input is "5511969230546", '
            'it should produce https://wa.me/5511969230546', () async {
          await whatsapp.launchChat(number: '5511969230546');

          expect(capturedUris.single.toString(), 'https://wa.me/5511969230546');
        });

        test('when the number is a US format with country code, '
            'it should strip the formatting and produce the correct URI', () async {
          await whatsapp.launchChat(number: '+1 (415) 555-2671');

          expect(capturedUris.single.toString(), 'https://wa.me/14155552671');
        });

        test('when the number has leading and trailing whitespace, '
            'it should strip spaces and produce the correct URI', () async {
          await whatsapp.launchChat(number: '  5511969230546  ');

          expect(capturedUris.single.toString(), 'https://wa.me/5511969230546');
        });
      });

      group('when handling the message parameter', () {
        test('when a message is provided with a simple value, '
            'it should include a text query parameter', () async {
          await whatsapp.launchChat(number: '551198887777', message: 'Hello');

          expect(capturedUris.single.queryParametersAll['text'], equals(['Hello']));
        });

        test('when a message contains spaces and accented characters (Cataquí), '
            'it should percent-encode them correctly', () async {
          await whatsapp.launchChat(number: '551198887777', message: 'Hey, found you on Cataquí');

          expect(capturedUris.single.toString(), contains('text=Hey%2C+found+you+on+Cataqu%C3%AD'));
        });

        test('when the message is null, '
            'it should NOT include any text query parameter', () async {
          await whatsapp.launchChat(number: '551198887777');

          expect(capturedUris.single.queryParametersAll, isEmpty);
        });

        test('when the message is an empty string, '
            'it should NOT include any text query parameter', () async {
          await whatsapp.launchChat(number: '551198887777', message: '');

          expect(capturedUris.single.queryParametersAll, isEmpty);
        });
      });

      group('when validating the number', () {
        test('when the number is an empty string, '
            'it should throw an ArgumentError', () async {
          expect(() => whatsapp.launchChat(number: ''), throwsArgumentError);
        });

        test('when the number contains only non-digit characters, '
            'it should throw an ArgumentError', () async {
          expect(() => whatsapp.launchChat(number: '+-- () '), throwsArgumentError);
        });
      });

      group('when reporting the launch result', () {
        test('when the launcher returns true, '
            'it should return true', () async {
          final result = await whatsapp.launchChat(number: '551198887777');

          expect(result, isTrue);
        });

        test('when the launcher returns false, '
            'it should return false', () async {
          whatsapp = Whatsapp.test(launcher: (_) async => false, isWeb: true);

          final result = await whatsapp.launchChat(number: '551198887777');

          expect(result, isFalse);
        });
      });
    });

    group('when on mobile (isWeb: false)', () {
      group('when WhatsApp is available', () {
        late List<Uri> capturedUris;
        late Whatsapp whatsapp;

        setUp(() {
          capturedUris = [];
          whatsapp = Whatsapp.test(
            launcher: (uri) async {
              capturedUris.add(uri);
              return true;
            },
          );
        });

        test('when launching with a clean number, '
            'it should call the launcher with whatsapp://send', () async {
          await whatsapp.launchChat(number: '551198887777');

          expect(capturedUris.single.toString(), 'whatsapp://send?phone=551198887777');
        });

        test('when the number has formatting, '
            'it should strip it and pass digits only', () async {
          await whatsapp.launchChat(number: '+55 (11) 9888-7777');

          expect(capturedUris.single.toString(), 'whatsapp://send?phone=551198887777');
        });

        test('when a message is provided, '
            'it should include the text query parameter', () async {
          await whatsapp.launchChat(number: '551198887777', message: 'Hello');

          expect(capturedUris.single.queryParametersAll['text'], equals(['Hello']));
        });

        test('when a message contains special characters, '
            'it should percent-encode them', () async {
          await whatsapp.launchChat(number: '551198887777', message: 'Hey, found you on Cataquí');

          expect(capturedUris.single.toString(), contains('text=Hey%2C+found+you+on+Cataqu%C3%AD'));
        });

        test('when the message is null, '
            'it should NOT include a text query parameter', () async {
          await whatsapp.launchChat(number: '551198887777');

          expect(capturedUris.single.queryParametersAll.containsKey('text'), isFalse);
        });

        test('when the message is empty, '
            'it should NOT include a text query parameter', () async {
          await whatsapp.launchChat(number: '551198887777', message: '');

          expect(capturedUris.single.queryParametersAll.containsKey('text'), isFalse);
        });

        test('when the launcher returns true, '
            'it should return true', () async {
          final result = await whatsapp.launchChat(number: '551198887777');

          expect(result, isTrue);
        });

        test('when the launcher returns true, '
            'it should NOT call the fallback wa.me URI', () async {
          await whatsapp.launchChat(number: '551198887777');

          expect(capturedUris, hasLength(1));
        });
      });

      group('when WhatsApp app is unavailable', () {
        late List<Uri> capturedUris;
        late Whatsapp whatsapp;

        setUp(() {
          capturedUris = [];
          whatsapp = Whatsapp.test(
            launcher: (uri) async {
              capturedUris.add(uri);
              return capturedUris.length == 2;
            },
          );
        });

        test('when the native scheme fails, '
            'it should fall back to https://wa.me', () async {
          await whatsapp.launchChat(number: '551198887777');

          expect(capturedUris, hasLength(2));
          expect(capturedUris[0].toString(), 'whatsapp://send?phone=551198887777');
          expect(capturedUris[1].toString(), 'https://wa.me/551198887777');
        });

        test('when the native scheme fails, '
            'it should return the fallback launch result', () async {
          final result = await whatsapp.launchChat(number: '551198887777');

          expect(result, isTrue);
        });

        test('when the native scheme throws a PlatformException, '
            'it should fall back to https://wa.me', () async {
          final whatsapp = Whatsapp.test(
            launcher: (uri) async {
              capturedUris.add(uri);
              if (capturedUris.length == 1) {
                throw PlatformException(code: 'ACTIVITY_NOT_FOUND', message: 'No Activity found');
              }
              return true;
            },
          );

          final result = await whatsapp.launchChat(number: '551198887777');

          expect(capturedUris, hasLength(2));
          expect(capturedUris[0].toString(), 'whatsapp://send?phone=551198887777');
          expect(capturedUris[1].toString(), 'https://wa.me/551198887777');
          expect(result, isTrue);
        });

        test('when both native and fallback fail, '
            'it should return false', () async {
          whatsapp = Whatsapp.test(launcher: (_) async => false);

          final result = await whatsapp.launchChat(number: '551198887777');

          expect(result, isFalse);
        });

        test('when the native scheme fails with a message, '
            'it should pass the message to the fallback', () async {
          await whatsapp.launchChat(number: '551198887777', message: 'Hello');

          expect(capturedUris, hasLength(2));
          expect(capturedUris[0].toString(), 'whatsapp://send?phone=551198887777&text=Hello');
          expect(capturedUris[1].toString(), 'https://wa.me/551198887777?text=Hello');
        });
      });

      group('when validating the number', () {
        test('when the number is an empty string, '
            'it should throw an ArgumentError', () async {
          final whatsapp = Whatsapp.test(launcher: (_) async => true);

          expect(() => whatsapp.launchChat(number: ''), throwsArgumentError);
        });

        test('when the number contains only non-digit characters, '
            'it should throw an ArgumentError', () async {
          final whatsapp = Whatsapp.test(launcher: (_) async => true);

          expect(() => whatsapp.launchChat(number: '+-- () '), throwsArgumentError);
        });
      });
    });
  });
}
