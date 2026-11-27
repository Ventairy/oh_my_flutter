import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  const address = 'Poster.Name+tag@Mail.Example.com';

  group('Email.parse', () {
    test('when the address has surrounding spaces, it should preserve only the address', () {
      expect(Email.parse(' $address ').address, address);
    });

    for (final input in ['poster@example', 'Poster <$address>', 'mailto:$address']) {
      test('when the input is $input, it should throw a FormatException', () {
        expect(() => Email.parse(input), throwsFormatException);
      });
    }
  });

  group('Email.tryParse', () {
    test('when the address is valid, it should return the parsed address', () {
      expect(Email.tryParse(address)?.address, address);
    });

    test('when the address is invalid, it should return null', () {
      expect(Email.tryParse('incomplete'), isNull);
    });
  });

  group('Email.send', () {
    late Uri draft;
    late Email email;

    setUp(() {
      email = Email.test(
        address,
        launcher: (uri) async {
          draft = uri;
          return true;
        },
      );
    });

    test('when both fields are omitted, it should open a recipient-only draft', () async {
      await email.send();
      expect(draft.toString(), 'mailto:$address');
    });

    test('when the body is omitted, it should open a draft with only the subject', () async {
      await email.send(subject: 'Hello');
      expect(draft.queryParameters, {'subject': 'Hello'});
    });

    test('when the subject is omitted, it should open a draft with only the body', () async {
      await email.send(body: 'Hello there');
      expect(draft.toString(), 'mailto:$address?body=Hello%20there');
    });

    test('when draft text includes special characters, it should preserve each field', () async {
      const subject = 'Café + tea & 5% #1';
      const body = 'Olá + hello\nA & B #2 at 50%';
      await email.send(body: body, subject: subject);
      expect(draft.queryParameters, {'subject': subject, 'body': body});
    });

    test('when the body is empty, it should keep the subject and empty body', () async {
      await email.send(body: '', subject: 'Hello');
      expect(draft.queryParameters, {'subject': 'Hello', 'body': ''});
    });

    test('when the platform accepts the draft, it should return true', () async {
      expect(await email.send(), isTrue);
    });

    test('when the platform declines the draft, it should return false', () async {
      final email = Email.test(address, launcher: (_) async => false);
      expect(await email.send(), isFalse);
    });

    test('when the platform reports an error, it should propagate that error', () async {
      final error = StateError('Mail app unavailable');
      final email = Email.test(address, launcher: (_) async => throw error);
      await expectLater(email.send(), throwsA(same(error)));
    });
  });
}
