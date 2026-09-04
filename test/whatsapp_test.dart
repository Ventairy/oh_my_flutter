import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('Whatsapp', () {
    group('when constructing a recipient', () {
      test(
        'when a formatted phone number is supplied, '
        'it should accept the identifier',
        () {
          expect(
            Whatsapp('+1 (202) 555-0123').toDisplayString(),
            '+1 202-555-0123',
          );
        },
      );

      test(
        'when an unformatted phone number is supplied, '
        'it should accept the identifier',
        () {
          expect(
            Whatsapp('12025550123').toDisplayString(),
            '+1 202-555-0123',
          );
        },
      );

      test(
        'when a username omits the at sign, it should add it for display',
        () {
          expect(Whatsapp('ventairy').toDisplayString(), '@ventairy');
        },
      );

      test(
        'when a username includes the at sign, '
        'it should retain one for display',
        () {
          expect(Whatsapp('@ventairy').toDisplayString(), '@ventairy');
        },
      );

      test(
        'when a username contains uppercase letters, '
        'it should normalize them to lowercase',
        () {
          expect(Whatsapp('@Ventairy').toDisplayString(), '@ventairy');
        },
      );

      test(
        'when an identifier has surrounding whitespace, '
        'it should trim the value',
        () {
          expect(Whatsapp('  @Ventairy  ').toDisplayString(), '@ventairy');
        },
      );

      test(
        'when an ambiguous identifier is not a valid phone number, '
        'it should resolve it as a username',
        () {
          expect(Whatsapp('123.ventairy').toDisplayString(), '@123.ventairy');
        },
      );

      test(
        'when the identifier is empty, it should throw a FormatException',
        () {
          expect(() => Whatsapp(''), throwsFormatException);
        },
      );

      test(
        'when a username contains an unsupported character, '
        'it should throw a FormatException',
        () {
          expect(() => Whatsapp('@ventairy-name'), throwsFormatException);
        },
      );

      test(
        'when a username is shorter than three characters, '
        'it should throw a FormatException',
        () {
          expect(() => Whatsapp('@ab'), throwsFormatException);
        },
      );

      test(
        'when a username is longer than thirty-five characters, '
        'it should throw a FormatException',
        () {
          final username = List.filled(36, 'a').join();

          expect(() => Whatsapp('@$username'), throwsFormatException);
        },
      );

      test(
        'when an explicit username contains only digits, '
        'it should throw a FormatException',
        () {
          expect(() => Whatsapp('@123'), throwsFormatException);
        },
      );

      test(
        'when a phone number has no country calling code, '
        'it should throw a FormatException',
        () {
          expect(() => Whatsapp('11 91234-5678'), throwsFormatException);
        },
      );

      test(
        'when a phone number has an invalid length, '
        'it should throw a FormatException',
        () {
          expect(() => Whatsapp('+55 11 123'), throwsFormatException);
        },
      );
    });

    group('when formatting a recipient for display', () {
      test(
        'when the recipient is a username, '
        'it should return the normalized username',
        () {
          expect(Whatsapp('Ventairy.Dev').toDisplayString(), '@ventairy.dev');
        },
      );

      test(
        'when the recipient is a phone number, '
        'it should return the country format',
        () {
          expect(
            Whatsapp('+1 (415) 555-2671').toDisplayString(),
            '+1 415-555-2671',
          );
        },
      );
    });

    group('when opening a chat on web', () {
      late List<Uri> launchedUris;

      setUp(() {
        launchedUris = [];
      });

      Future<bool> launch(Uri uri) async {
        launchedUris.add(uri);
        return true;
      }

      test(
        'when the recipient is a phone number, '
        'it should launch the phone wa.me URI',
        () async {
          final whatsapp = Whatsapp.test(
            '+1 (202) 555-0123',
            launcher: launch,
            isWeb: true,
          );

          await whatsapp.chat();

          expect(
            launchedUris.single.toString(),
            'https://wa.me/12025550123',
          );
        },
      );

      test(
        'when the recipient is a username, '
        'it should launch the username wa.me URI',
        () async {
          final whatsapp = Whatsapp.test(
            '@Ventairy',
            launcher: launch,
            isWeb: true,
          );

          await whatsapp.chat();

          expect(
            launchedUris.single.toString(),
            'https://wa.me/?username=ventairy',
          );
        },
      );

      test(
        'when a message is supplied, it should encode it in the URI',
        () async {
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: launch,
            isWeb: true,
          );

          await whatsapp.chat(message: 'Olá, Ventairy!');

          expect(
            launchedUris.single.toString(),
            'https://wa.me/?username=ventairy&text=Ol%C3%A1%2C+Ventairy%21',
          );
        },
      );

      test(
        'when a phone chat has a message, '
        'it should include it in the phone wa.me URI',
        () async {
          final whatsapp = Whatsapp.test(
            '+1 (202) 555-0123',
            launcher: launch,
            isWeb: true,
          );

          await whatsapp.chat(message: 'Hello');

          expect(
            launchedUris.single.toString(),
            'https://wa.me/12025550123?text=Hello',
          );
        },
      );

      test(
        'when the message is empty, it should omit the text parameter',
        () async {
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: launch,
            isWeb: true,
          );

          await whatsapp.chat(message: '');

          expect(
            launchedUris.single.queryParameters.containsKey('text'),
            isFalse,
          );
        },
      );

      test(
        'when the launcher rejects the URI, it should return false',
        () async {
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: (_) async => false,
            isWeb: true,
          );

          expect(await whatsapp.chat(), isFalse);
        },
      );
    });

    group('when opening a chat on mobile', () {
      test(
        'when the recipient is a phone number, '
        'it should launch the native phone URI',
        () async {
          late Uri launchedUri;
          final whatsapp = Whatsapp.test(
            '+1 (202) 555-0123',
            launcher: (uri) async {
              launchedUri = uri;
              return true;
            },
          );

          await whatsapp.chat();

          expect(
            launchedUri.toString(),
            'whatsapp://send?phone=12025550123',
          );
        },
      );

      test(
        'when the recipient is a username, '
        'it should launch the native username URI',
        () async {
          late Uri launchedUri;
          final whatsapp = Whatsapp.test(
            '@Ventairy',
            launcher: (uri) async {
              launchedUri = uri;
              return true;
            },
          );

          await whatsapp.chat();

          expect(
            launchedUri.toString(),
            'whatsapp://send?username=ventairy',
          );
        },
      );

      test(
        'when a message is supplied, '
        'it should encode it in the native URI',
        () async {
          late Uri launchedUri;
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: (uri) async {
              launchedUri = uri;
              return true;
            },
          );

          await whatsapp.chat(message: 'Olá, Ventairy!');

          expect(
            launchedUri.toString(),
            'whatsapp://send?username=ventairy&text=Ol%C3%A1%2C+Ventairy%21',
          );
        },
      );

      test(
        'when a phone chat has a message, '
        'it should include it in the native phone URI',
        () async {
          late Uri launchedUri;
          final whatsapp = Whatsapp.test(
            '+1 (202) 555-0123',
            launcher: (uri) async {
              launchedUri = uri;
              return true;
            },
          );

          await whatsapp.chat(message: 'Hello');

          expect(
            launchedUri.toString(),
            'whatsapp://send?phone=12025550123&text=Hello',
          );
        },
      );

      test(
        'when the native phone launch returns false, '
        'it should fall back to the phone wa.me URI',
        () async {
          final launchedUris = <Uri>[];
          final whatsapp = Whatsapp.test(
            '+1 (202) 555-0123',
            launcher: (uri) async {
              launchedUris.add(uri);
              return launchedUris.length == 2;
            },
          );

          await whatsapp.chat();

          expect(
            launchedUris.map((uri) => uri.toString()),
            <String>[
              'whatsapp://send?phone=12025550123',
              'https://wa.me/12025550123',
            ],
          );
        },
      );

      test(
        'when the native username launch returns false, '
        'it should fall back to the username wa.me URI',
        () async {
          final launchedUris = <Uri>[];
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: (uri) async {
              launchedUris.add(uri);
              return launchedUris.length == 2;
            },
          );

          await whatsapp.chat();

          expect(
            launchedUris.map((uri) => uri.toString()),
            <String>[
              'whatsapp://send?username=ventairy',
              'https://wa.me/?username=ventairy',
            ],
          );
        },
      );

      test(
        'when the native launch throws, it should launch the web fallback',
        () async {
          final launchedUris = <Uri>[];
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: (uri) async {
              launchedUris.add(uri);
              if (launchedUris.length == 1) {
                throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
              }
              return true;
            },
          );

          await whatsapp.chat();

          expect(launchedUris, hasLength(2));
        },
      );

      test(
        'when the native launch succeeds, it should return true',
        () async {
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: (_) async => true,
          );

          expect(await whatsapp.chat(), isTrue);
        },
      );

      test(
        'when the fallback launch returns false, it should return false',
        () async {
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: (_) async => false,
          );

          expect(await whatsapp.chat(), isFalse);
        },
      );

      test(
        'when the final fallback throws, it should propagate the exception',
        () async {
          var launchCount = 0;
          final whatsapp = Whatsapp.test(
            '@ventairy',
            launcher: (_) async {
              launchCount += 1;
              if (launchCount == 1) return false;
              throw StateError('fallback failed');
            },
          );

          expect(whatsapp.chat, throwsStateError);
        },
      );
    });
  });
}
