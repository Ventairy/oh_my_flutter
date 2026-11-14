part of 'phone_number_text_input_formatter.dart';

/// Supplies the complete outcome of formatting phone-number input.
@immutable
final class PhoneNumberTextInputFormatterResult {
  const new _({
    required this.textEditingValue,
    required this.country,
    required this.internationalValue,
  });

  /// The nationally formatted field text, selection, and composing range.
  final TextEditingValue textEditingValue;

  /// The country resolved for the formatted number.
  final Country country;

  /// The unformatted international value represented by the field.
  ///
  /// The result is empty when the field contains no national digits. Otherwise,
  /// it starts with `+` and includes [country]'s calling code, even while the
  /// national number is incomplete.
  final String internationalValue;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PhoneNumberTextInputFormatterResult &&
            other.textEditingValue == textEditingValue &&
            other.country == country &&
            other.internationalValue == internationalValue;
  }

  @override
  int get hashCode {
    return Object.hash(textEditingValue, country, internationalValue);
  }

  @override
  String toString() {
    return 'PhoneNumberTextInputFormatterResult('
        'textEditingValue: $textEditingValue, '
        'country: $country, '
        'internationalValue: $internationalValue'
        ')';
  }
}
