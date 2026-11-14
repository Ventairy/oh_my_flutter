import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  const formatter = HandleTextInputFormatter();

  group('HandleTextInputFormatter', () {
    for (final scenario in <({String name, String input, String expected})>[
      (name: 'a prefixed handle', input: ' @Some.Name_42 ', expected: 'Some.Name_42'),
      (name: 'Unicode and whitespace', input: '@@João\t名\u00a0🌻\u0085_\u2003.\u202f+\n@', expected: 'João名🌻_.+'),
      (name: 'a profile URL', input: 'https://example.com/@Some.Name', expected: 'https://example.com/Some.Name'),
      (name: 'only excluded characters', input: '@ \t\n@', expected: ''),
      (name: 'an empty handle', input: '', expected: ''),
    ]) {
      test('when receiving ${scenario.name}, it should remove only at signs and whitespace', () {
        expect(
          formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: scenario.input)).text,
          scenario.expected,
        );
      });
    }

    test('when the handle needs no filtering, it should preserve the complete editing value', () {
      const value = TextEditingValue(
        text: 'Some.שם_名前🌻42',
        selection: TextSelection(baseOffset: 2, extentOffset: 5, affinity: .upstream, isDirectional: true),
      );
      expect(formatter.formatEditUpdate(TextEditingValue.empty, value), value);
    });

    test('when excluded characters surround a reverse selection, it should retain the selected handle characters', () {
      const edit = TextEditingValue(
        text: ' @A 🌻@ B ',
        selection: TextSelection(baseOffset: 9, extentOffset: 3, affinity: .upstream, isDirectional: true),
      );
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, edit),
        const TextEditingValue(
          text: 'A🌻B',
          selection: TextSelection(baseOffset: 4, extentOffset: 1, affinity: .upstream, isDirectional: true),
        ),
      );
    });

    test('when a prefix before the caret is removed, it should leave the caret at the beginning', () {
      expect(
        formatter.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(text: ' @AB', selection: TextSelection.collapsed(offset: 2)),
        ),
        const TextEditingValue(text: 'AB', selection: TextSelection.collapsed(offset: 0)),
      );
    });

    test('when a selection is replaced by pasted text, it should preserve the surrounding handle and caret', () {
      expect(
        formatter.formatEditUpdate(
          const TextEditingValue(text: 'before.old.after', selection: TextSelection(baseOffset: 7, extentOffset: 10)),
          const TextEditingValue(text: 'before. @New 名 .after', selection: TextSelection.collapsed(offset: 15)),
        ),
        const TextEditingValue(text: 'before.New名.after', selection: TextSelection.collapsed(offset: 11)),
      );
    });

    test('when an IME is composing, it should leave its text and editing ranges intact', () {
      const composingValue = TextEditingValue(
        text: '@名 前',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 1, end: 4),
      );
      expect(formatter.formatEditUpdate(TextEditingValue.empty, composingValue), composingValue);
    });

    test('when composition is committed, it should normalize the handle and retain the committed caret', () {
      const composingValue = TextEditingValue(
        text: '@名 前',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 1, end: 4),
      );
      expect(
        formatter.formatEditUpdate(composingValue, composingValue.copyWith(composing: TextRange.empty)),
        const TextEditingValue(text: '名前', selection: TextSelection.collapsed(offset: 2)),
      );
    });

    test('when composition commits with a collapsed range, it should move that range with the filtered text', () {
      expect(
        formatter.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(
            text: '@名 前',
            selection: TextSelection.collapsed(offset: 4),
            composing: TextRange.collapsed(4),
          ),
        ),
        const TextEditingValue(
          text: '名前',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.collapsed(2),
        ),
      );
    });

    test('when an edit has no selection, it should preserve the absent selection while filtering', () {
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '@Some Name')),
        const TextEditingValue(text: 'SomeName'),
      );
    });
  });
}
