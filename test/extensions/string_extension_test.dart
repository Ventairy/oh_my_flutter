import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('StringExtension', () {
    group('when checking whether a value contains only digits', () {
      test('when every character is a digit, it should return true', () {
        expect('0123456789'.isDigitsOnly, isTrue);
      });

      test('when the value is empty, it should return false', () {
        expect(''.isDigitsOnly, isFalse);
      });

      test('when the value contains a letter, it should return false', () {
        expect('123a'.isDigitsOnly, isFalse);
      });

      test('when the value contains whitespace, it should return false', () {
        expect('123 456'.isDigitsOnly, isFalse);
      });

      test('when the value contains a decimal point, it should return false', () {
        expect('123.45'.isDigitsOnly, isFalse);
      });

      test('when the value contains a sign, it should return false', () {
        expect('-123'.isDigitsOnly, isFalse);
      });
    });

    for (final scenario in [
      (
        name: 'email',
        isValid: (String value) => value.isValidEmail,
        valid: [
          'poster@example.com',
          ' Poster.Name+gigs@EXAMPLE.COM ',
          "post'er@example.com",
          '${''.padRight(308, 'a')}@example.com',
        ],
        invalid: [
          '',
          ' ',
          'poster@example',
          'poster@example.c',
          '.poster@example.com',
          'poster.@example.com',
          'poster..name@example.com',
          "poster'@example.com",
          'poster name@example.com',
          'póster@example.com',
          'Poster <poster@example.com>',
          'mailto:poster@example.com',
          '${''.padRight(309, 'a')}@example.com',
        ],
      ),
      (
        name: 'phone number',
        isValid: (String value) => value.isValidPhoneNumber,
        valid: ['+12025550123', ' +55 (11) 91234-5678 ', '+551133334444'],
        invalid: ['', ' ', '2025550123', '+1', '+19999999999', '+5511212345678', '+15556625497', '@local_handle'],
      ),
      (
        name: 'Telegram username',
        isValid: (String value) => value.isValidTelegramUsername,
        valid: ['abcd', ''.padRight(32, 'a'), ' Poster_123 ', ' @Poster_123 '],
        invalid: ['abc', ''.padRight(33, 'a'), '1poster', '_poster', 'poster_', 'poster.name'],
      ),
      (
        name: 'Instagram username',
        isValid: (String value) => value.isValidInstagramUsername,
        valid: ['a', ''.padRight(30, 'a'), '12345', '_poster_', ' Poster.Name ', ' @Poster.Name '],
        invalid: [''.padRight(31, 'a'), '.poster', 'poster.', 'poster..name', 'poster-name'],
      ),
      (
        name: 'WhatsApp username',
        isValid: (String value) => value.isValidWhatsappUsername,
        valid: [
          'abc',
          ''.padRight(35, 'a'),
          '_poster_',
          '123.ventairy',
          ' @Poster.Name ',
          'poster.company',
          'poster_www.name',
        ],
        invalid: [
          'ab',
          ''.padRight(36, 'a'),
          '12345',
          '___',
          '123.45',
          '.poster',
          'poster.',
          'poster..name',
          'www.poster',
          'poster-name',
          '@POSTER.COM',
          for (final suffix in ['com', 'org', 'net', 'int', 'edu', 'gov', 'mil', 'arpa', 'html', 'htm', 'txt', 'xml'])
            'poster.$suffix',
        ],
      ),
    ]) {
      for (final value in scenario.valid) {
        test('when checking the ${scenario.name} "$value", it should accept its format', () {
          expect(scenario.isValid(value), isTrue);
        });
      }

      for (final value in scenario.invalid) {
        test('when checking the ${scenario.name} "$value", it should reject its format', () {
          expect(scenario.isValid(value), isFalse);
        });
      }
    }

    for (final scenario in [
      (
        name: 'Telegram',
        isValid: (String value) => value.isValidTelegramUsername,
        reserved: [
          'addemoji',
          'addlist',
          'addstickers',
          'addstyle',
          'addtheme',
          'auction',
          'auth',
          'boost',
          'call',
          'confirmphone',
          'contact',
          'giftcode',
          'invoice',
          'joinchat',
          'login',
          'proxy',
          'setlanguage',
          'share',
          'socks',
        ],
      ),
      (
        name: 'Instagram',
        isValid: (String value) => value.isValidInstagramUsername,
        reserved: ['p', 'reel', 'reels', 'tv', 'stories', 'explore', 'direct', 'accounts'],
      ),
    ]) {
      for (final username in scenario.reserved) {
        test(
          'when the ${scenario.name} username is the reserved path $username, it should reject both entry forms',
          () {
            expect([scenario.isValid(username), scenario.isValid(' @${username.toUpperCase()} ')], [false, false]);
          },
        );
      }
    }

    for (final scenario in [
      (name: 'Telegram', isValid: (String value) => value.isValidTelegramUsername),
      (name: 'Instagram', isValid: (String value) => value.isValidInstagramUsername),
      (name: 'WhatsApp', isValid: (String value) => value.isValidWhatsappUsername),
    ]) {
      for (final value in [
        '',
        ' ',
        '@',
        '@@poster',
        ' @ poster ',
        'poster name',
        'poster@name',
        'https://t.me/poster',
        'https://instagram.com/poster',
        'póster',
        'Kposter',
        'poſter',
      ]) {
        test('when the ${scenario.name} username is "$value", it should reject the malformed input', () {
          expect(scenario.isValid(value), isFalse);
        });
      }
    }
  });
}
