import 'package:flutter/services.dart';

/// Keeps account handles free of `@` prefixes and whitespace during entry.
///
/// Case, Unicode, and other characters are preserved. Service-specific character
/// restrictions and length limits remain the application's responsibility.
/// Active composition is preserved until committed, and selection follows edits.
/// Like other input formatters, this does not rewrite app-assigned controller
/// values or add a visible prefix.
///
/// See the [handle input guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/text_input_formatters.md#handletextinputformatter).
final class HandleTextInputFormatter extends TextInputFormatter {
  /// Creates a formatter for bare account handles.
  const new();

  static final _excludedCharacters = RegExp(r'[@\s\u0085]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Leave the IME's in-progress text intact until it commits the composition.
    if (!newValue.composing.isCollapsed) return newValue;
    final normalizedText = newValue.text.replaceAll(_excludedCharacters, '');
    if (normalizedText == newValue.text) return newValue;

    int normalizedOffset(int offset) =>
        offset < 0 ? offset : newValue.text.substring(0, offset).replaceAll(_excludedCharacters, '').length;

    return newValue.copyWith(
      text: normalizedText,
      selection: newValue.selection.copyWith(
        baseOffset: normalizedOffset(newValue.selection.baseOffset),
        extentOffset: normalizedOffset(newValue.selection.extentOffset),
      ),
      composing: newValue.composing.isValid
          ? TextRange.collapsed(normalizedOffset(newValue.composing.start))
          : newValue.composing,
    );
  }
}
