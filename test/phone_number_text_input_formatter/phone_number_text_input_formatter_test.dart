import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('PhoneNumberTextInputFormatter', () {
    test('when national digits are entered, it should return every value', () {
      final formatter = PhoneNumberTextInputFormatter(
        country: Country.brazil,
      );

      final result = formatter.formatEditUpdateWithResult(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '11969230546',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );

      expect(
        (
          result.textEditingValue.text,
          result.textEditingValue.selection,
          result.country,
          result.internationalValue,
          formatter.country,
        ),
        (
          '11 96923-0546',
          const TextSelection.collapsed(offset: 13),
          Country.brazil,
          '+5511969230546',
          Country.brazil,
        ),
      );
    });

    test('when the field is empty, it should return no calling code', () {
      final formatter = PhoneNumberTextInputFormatter(
        country: Country.brazil,
      );

      final result = formatter.formatEditUpdateWithResult(
        TextEditingValue.empty,
        TextEditingValue.empty,
      );

      expect(
        (result.textEditingValue, result.internationalValue),
        (TextEditingValue.empty, ''),
      );
    });

    test('when alternate numerals are entered, it should normalize them', () {
      final formatter = PhoneNumberTextInputFormatter(
        country: Country.unitedStates,
      );

      final result = formatter.formatEditUpdateWithResult(
        TextEditingValue.empty,
        const TextEditingValue(text: '２０２ ٥٥٥ ٠١٢٣'),
      );

      expect(
        (result.textEditingValue.text, result.internationalValue),
        ('(202) 555-0123', '+12025550123'),
      );
    });

    test(
      'when an international paste resolves elsewhere, it should return that country',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.brazil,
        );

        final result = formatter.formatEditUpdateWithResult(
          TextEditingValue.empty,
          const TextEditingValue(text: '+1 202-555-0123'),
        );

        expect(
          (
            result.textEditingValue.text,
            result.country,
            result.internationalValue,
            formatter.country,
          ),
          (
            '(202) 555-0123',
            Country.unitedStates,
            '+12025550123',
            Country.brazil,
          ),
        );
      },
    );

    test(
      'when direct formatting resolves elsewhere, it should reject the edit',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.brazil,
        );
        const oldValue = TextEditingValue(
          text: '11',
          selection: TextSelection.collapsed(offset: 2),
        );

        final value = formatter.formatEditUpdate(
          oldValue,
          const TextEditingValue(text: '+1 202-555-0123'),
        );

        expect(value, oldValue);
      },
    );

    test(
      'when an international paste matches the country, it should accept it',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.brazil,
        );

        final value = formatter.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(text: '+55 11 96923-0546'),
        );

        expect(value.text, '11 96923-0546');
      },
    );

    test('when a calling code is shared, it should retain the country', () {
      final formatter = PhoneNumberTextInputFormatter(
        country: Country.canada,
      );

      final result = formatter.formatEditUpdateWithResult(
        TextEditingValue.empty,
        const TextEditingValue(text: '+1 416-555-0123'),
      );

      expect(
        (result.country, result.internationalValue),
        (Country.canada, '+14165550123'),
      );
    });

    test(
      'when an international paste is unresolved, it should return the previous values',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.brazil,
        );
        const oldValue = TextEditingValue(
          text: '11 9692',
          selection: TextSelection.collapsed(offset: 7),
        );

        final result = formatter.formatEditUpdateWithResult(
          oldValue,
          const TextEditingValue(
            text: '+999 12',
            selection: TextSelection.collapsed(offset: 7),
          ),
        );

        expect(
          (
            result.textEditingValue,
            result.country,
            result.internationalValue,
          ),
          (oldValue, Country.brazil, '+55119692'),
        );
      },
    );

    test('when an edit exceeds the maximum, it should return the old value', () {
      final formatter = PhoneNumberTextInputFormatter(
        country: Country.unitedStates,
      );
      final accepted = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '2025550123'),
      );

      final result = formatter.formatEditUpdateWithResult(
        accepted,
        const TextEditingValue(text: '20255501234'),
      );

      expect(
        (result.textEditingValue, result.internationalValue),
        (accepted, '+12025550123'),
      );
    });

    test(
      'when a national value exceeds the maximum, it should preserve every digit',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.unitedStates,
        );
        const value = TextEditingValue(
          text: '11969230546',
          selection: TextSelection.collapsed(offset: 11),
        );

        final result = formatter.formatNationalValue(value);
        final formattedDigits = result.textEditingValue.text.replaceAll(
          RegExp(r'\D'),
          '',
        );
        final addedDigit = formatter.formatEditUpdateWithResult(
          result.textEditingValue,
          const TextEditingValue(text: '119692305467'),
        );

        expect(
          (
            formattedDigits,
            result.textEditingValue.selection.extentOffset,
            result.textEditingValue.text.length,
            result.internationalValue,
            addedDigit.textEditingValue,
          ),
          (
            '11969230546',
            result.textEditingValue.text.length,
            result.textEditingValue.text.length,
            '+111969230546',
            result.textEditingValue,
          ),
        );
      },
    );

    test(
      'when a detected country is reused, it should format the next edit there',
      () {
        final brazilFormatter = PhoneNumberTextInputFormatter(
          country: Country.brazil,
        );
        final detected = brazilFormatter.formatEditUpdateWithResult(
          TextEditingValue.empty,
          const TextEditingValue(text: '+1 202-555'),
        );
        final formatter = PhoneNumberTextInputFormatter(
          country: detected.country,
        );

        final result = formatter.formatEditUpdateWithResult(
          detected.textEditingValue,
          const TextEditingValue(text: '(202) 555-0123'),
        );

        expect(
          (
            result.textEditingValue.text,
            result.country,
            result.internationalValue,
          ),
          ('(202) 555-0123', Country.unitedStates, '+12025550123'),
        );
      },
    );

    test(
      'when punctuation is inserted, it should map selection and composing',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.unitedStates,
        );

        final result = formatter.formatEditUpdateWithResult(
          TextEditingValue.empty,
          const TextEditingValue(
            text: '202555',
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange(start: 0, end: 6),
          ),
        );

        expect(
          (
            result.textEditingValue.text,
            result.textEditingValue.selection,
            result.textEditingValue.composing,
          ),
          (
            '202-555',
            const TextSelection.collapsed(offset: 3),
            const TextRange(start: 0, end: 7),
          ),
        );
      },
    );

    test('when results match, they should have equal value semantics', () {
      final formatter = PhoneNumberTextInputFormatter(
        country: Country.brazil,
      );
      final first = formatter.formatNationalValue(
        const TextEditingValue(text: '11969230546'),
      );
      final second = formatter.formatNationalValue(
        const TextEditingValue(text: '11969230546'),
      );

      expect(
        (first == second, first.hashCode == second.hashCode),
        (true, true),
      );
    });

    test('when another region shares a calling code, it should detect that region from the number', () {
      final result = PhoneNumberTextInputFormatter(country: Country.brazil).formatEditUpdateWithResult(
        TextEditingValue.empty,
        const TextEditingValue(text: '+1 416 555 0123'),
      );
      expect(result.country, Country.canada);
    });

    test('when reformatting for any calling-code country, it should preserve national digits', () {
      final results = <String, String>{};
      for (final country in Country.values.where((candidate) => candidate.callingCode != null)) {
        final result = PhoneNumberTextInputFormatter(country: country).formatNationalValue(
          const TextEditingValue(text: '0123456789012345'),
        );
        final digits = result.textEditingValue.text.replaceAll(RegExp(r'\D'), '');
        if (digits != '0123456789012345') results[country.iso2] = digits;
      }
      expect(results, isEmpty);
    });

    test('when a country has no calling code, it should assert', () {
      expect(
        () => PhoneNumberTextInputFormatter(
          country: Country.antarctica,
        ),
        throwsAssertionError,
      );
    });

    test('when a country has a calling code, it should format normally', () {
      expect(
        () {
          for (final country in Country.values.where(
            (candidate) => candidate.callingCode != null,
          )) {
            PhoneNumberTextInputFormatter(country: country).formatEditUpdateWithResult(
              TextEditingValue.empty,
              const TextEditingValue(text: '1'),
            );
          }
        },
        returnsNormally,
      );
    });
  });
}
