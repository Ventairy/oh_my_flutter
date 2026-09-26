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

    test(
      'when edits reuse a formatter, it should match independent formatting',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.unitedStates,
        );
        const edits = [
          TextEditingValue(
            text: '202555',
            selection: TextSelection.collapsed(offset: 6),
          ),
          TextEditingValue(
            text: '2025550',
            selection: TextSelection.collapsed(offset: 7),
          ),
          TextEditingValue(
            text: '20255501',
            selection: TextSelection.collapsed(offset: 8),
          ),
          TextEditingValue(
            text: '2025550',
            selection: TextSelection.collapsed(offset: 7),
          ),
          TextEditingValue(
            text: '20295550',
            selection: TextSelection.collapsed(offset: 4),
          ),
          TextEditingValue(
            text: '2029550123',
            selection: TextSelection.collapsed(offset: 10),
          ),
        ];
        final actual = <PhoneNumberTextInputFormatterResult>[];
        final expected = <PhoneNumberTextInputFormatterResult>[];
        var oldValue = TextEditingValue.empty;

        for (final edit in edits) {
          final result = formatter.formatEditUpdateWithResult(oldValue, edit);
          actual.add(result);
          expected.add(
            PhoneNumberTextInputFormatter(
              country: Country.unitedStates,
            ).formatEditUpdateWithResult(oldValue, edit),
          );
          oldValue = result.textEditingValue;
        }

        expect(actual, expected);
      },
    );

    test(
      'when an international edit resolves another country, it should keep the selected formatter reusable',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.brazil,
        );
        final brazilian = formatter.formatNationalValue(
          const TextEditingValue(text: '11969230546'),
        );
        final international = formatter.formatEditUpdateWithResult(
          brazilian.textEditingValue,
          const TextEditingValue(text: '+1 202-555-0123'),
        );
        final reformatted = formatter.formatNationalValue(
          brazilian.textEditingValue,
        );

        expect(
          (international.country, reformatted),
          (Country.unitedStates, brazilian),
        );
      },
    );

    test(
      'when a later edit has composing text, it should map it like a fresh formatter',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.unitedStates,
        );
        final oldValue = formatter
            .formatNationalValue(
              const TextEditingValue(text: '2025550123'),
            )
            .textEditingValue;
        const edit = TextEditingValue(
          text: '202555',
          selection: TextSelection(
            baseOffset: 6,
            extentOffset: 3,
            isDirectional: true,
          ),
          composing: TextRange(start: 0, end: 6),
        );

        final result = formatter.formatEditUpdateWithResult(oldValue, edit);
        final freshResult = PhoneNumberTextInputFormatter(
          country: Country.unitedStates,
        ).formatEditUpdateWithResult(oldValue, edit);

        expect(result, freshResult);
      },
    );

    test(
      'when a prior value selects another formatting region, it should restore the selected region',
      () {
        final formatter =
            PhoneNumberTextInputFormatter(
              country: Country.unitedStates,
            )..formatNationalValue(
              const TextEditingValue(text: '011442071838750'),
            );

        final result = formatter.formatNationalValue(
          const TextEditingValue(text: '2025550123'),
        );
        final freshResult = PhoneNumberTextInputFormatter(
          country: Country.unitedStates,
        ).formatNationalValue(const TextEditingValue(text: '2025550123'));

        expect(result, freshResult);
      },
    );

    test(
      'when common national numbers are entered, it should preserve their output',
      () {
        final unitedStates =
            PhoneNumberTextInputFormatter(
              country: Country.unitedStates,
            ).formatEditUpdateWithResult(
              TextEditingValue.empty,
              const TextEditingValue(text: '2025550123'),
            );
        final brazil =
            PhoneNumberTextInputFormatter(
              country: Country.brazil,
            ).formatEditUpdateWithResult(
              TextEditingValue.empty,
              const TextEditingValue(text: '11969230546'),
            );

        expect(
          (
            unitedStates.textEditingValue.text,
            unitedStates.internationalValue,
            brazil.textEditingValue.text,
            brazil.internationalValue,
          ),
          (
            '(202) 555-0123',
            '+12025550123',
            '11 96923-0546',
            '+5511969230546',
          ),
        );
      },
    );

    test(
      'when a UK national prefix becomes complete, it should update the national digits',
      () {
        final formatter = PhoneNumberTextInputFormatter(
          country: Country.unitedKingdom,
        );
        final incomplete = formatter.formatEditUpdateWithResult(
          TextEditingValue.empty,
          const TextEditingValue(text: '0207'),
        );
        final complete = formatter.formatEditUpdateWithResult(
          incomplete.textEditingValue,
          const TextEditingValue(text: '0207031300'),
        );

        expect(
          (
            incomplete.textEditingValue.text,
            incomplete.internationalValue,
            complete.textEditingValue.text,
            complete.internationalValue,
          ),
          ('020 7', '+440207', '207031300', '+44207031300'),
        );
      },
    );

    test(
      'when national input starts with its country code, it should retain Andorra output',
      () {
        final result =
            PhoneNumberTextInputFormatter(
              country: Country.andorra,
            ).formatEditUpdateWithResult(
              TextEditingValue.empty,
              const TextEditingValue(text: '376312345'),
            );

        expect(
          (result.textEditingValue.text, result.internationalValue),
          ('312 345', '+376312345'),
        );
      },
    );

    test(
      'when a national prefix is entered, it should retain UAE output',
      () {
        final result =
            PhoneNumberTextInputFormatter(
              country: Country.unitedArabEmirates,
            ).formatEditUpdateWithResult(
              TextEditingValue.empty,
              const TextEditingValue(text: '0501234567'),
            );

        expect(
          (result.textEditingValue.text, result.internationalValue),
          ('501234567', '+971501234567'),
        );
      },
    );

    test(
      'when a shared calling-code region expands a local number, it should retain Antigua output',
      () {
        final result =
            PhoneNumberTextInputFormatter(
              country: Country.antiguaAndBarbuda,
            ).formatEditUpdateWithResult(
              TextEditingValue.empty,
              const TextEditingValue(text: '5814703'),
            );

        expect(
          (result.textEditingValue.text, result.internationalValue),
          ('(268) 581-4703', '+12685814703'),
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
