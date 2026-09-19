import 'package:dlibphonenumber/dlibphonenumber.dart' as parser;
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../country/country.dart';

part 'phone_number_text_input_formatter_result.dart';

/// Formats editable phone-number text for a selected [Country].
///
/// National input uses [country]. Use [formatEditUpdateWithResult] when an
/// explicitly international value may select another country, then create a
/// new formatter with the returned country before the next edit.
///
/// See the [phone number guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/phone_number.md)
/// for field integration and country-change examples.
final class PhoneNumberTextInputFormatter extends TextInputFormatter {
  /// Creates a formatter for [country].
  ///
  /// The country must have a calling code.
  new({required this.country})
    : assert(
        country.callingCode != null,
        'country must have a calling code.',
      );

  static final parser.PhoneNumberUtil _phoneUtil = parser.PhoneNumberUtil.instance;

  /// The country used to interpret national input.
  final Country country;

  /// Formats an edit and returns its text, country, and international value.
  ///
  /// A value beginning with `+` may return a country different from [country].
  PhoneNumberTextInputFormatterResult formatEditUpdateWithResult(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalizedInput = _normalizePhoneInput(newValue.text);
    final parsedInput = normalizedInput.startsWith('+')
        ? _parseInternationalInput(normalizedInput, country)
        : _parseNationalInput(
            _extractNormalizedDigits(normalizedInput),
            country,
          );

    if (parsedInput == null) return _rejectedEditResult(oldValue);

    final oldDigitCount = _extractNormalizedDigits(oldValue.text).length;
    final nationalDigitLimit = _nationalDigitLimit(parsedInput.country);
    if (parsedInput.nationalDigits.length > nationalDigitLimit && parsedInput.nationalDigits.length > oldDigitCount) {
      return _rejectedEditResult(oldValue);
    }

    return _formatNationalDigits(
      source: newValue,
      country: parsedInput.country,
      nationalDigits: parsedInput.nationalDigits,
    );
  }

  /// Formats the national digits already stored in [value] for [country].
  ///
  /// This preserves every digit, along with its selection and composing
  /// positions, so a country picker can reformat incomplete input without
  /// treating it as newly entered text.
  PhoneNumberTextInputFormatterResult formatNationalValue(
    TextEditingValue value,
  ) {
    return _formatNationalDigits(
      source: value,
      country: country,
      nationalDigits: _extractNormalizedDigits(value.text),
    );
  }

  /// Formats an edit that must remain associated with [country].
  ///
  /// Use [formatEditUpdateWithResult] instead when explicit international
  /// input may change the selected country. This fixed-country override rejects
  /// such a change because Flutter's formatter contract can return only text.
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final result = formatEditUpdateWithResult(oldValue, newValue);
    if (result.country != country) return oldValue;
    return result.textEditingValue;
  }

  PhoneNumberTextInputFormatterResult _rejectedEditResult(
    TextEditingValue oldValue,
  ) {
    final nationalDigits = _extractNormalizedDigits(oldValue.text);
    return PhoneNumberTextInputFormatterResult._(
      textEditingValue: oldValue,
      country: country,
      internationalValue: _buildInternationalValue(
        country: country,
        nationalDigits: nationalDigits,
      ),
    );
  }

  ({Country country, String nationalDigits})? _parseInternationalInput(
    String normalizedInput,
    Country selectedCountry,
  ) {
    final internationalDigits = normalizedInput.substring(1);
    if (internationalDigits.isEmpty) {
      return (country: selectedCountry, nationalDigits: '');
    }

    final callingCode = _longestCallingCodePrefix(internationalDigits);
    if (callingCode == null) return null;

    final nationalDigits = internationalDigits.substring(callingCode.length);
    if (selectedCountry.callingCode == callingCode) {
      return (country: selectedCountry, nationalDigits: nationalDigits);
    }
    try {
      final parsed = _phoneUtil.parse(normalizedInput, 'ZZ');
      final region =
          _phoneUtil.getRegionCodeForNumber(parsed) ?? _phoneUtil.getRegionCodeForCountryCode(parsed.countryCode);
      final detectedCountry = Country.tryFromIso2(region);
      if (detectedCountry?.callingCode == callingCode) {
        return (country: detectedCountry!, nationalDigits: _phoneUtil.getNationalSignificantNumber(parsed));
      }
    } on parser.NumberParseException {
      // A calling code alone can still select its main region.
    }
    final mainRegion = _phoneUtil.getRegionCodeForCountryCode(int.parse(callingCode));
    final detectedCountry = Country.tryFromIso2(mainRegion);
    if (detectedCountry?.callingCode != callingCode) return null;
    return (country: detectedCountry!, nationalDigits: nationalDigits);
  }

  ({Country country, String nationalDigits}) _parseNationalInput(String digits, Country selectedCountry) {
    if (digits.isEmpty ||
        digits.length > _nationalDigitLimit(selectedCountry) ||
        _phoneUtil.getMetadataForRegion(regionCode: selectedCountry.iso2) == null) {
      return (country: selectedCountry, nationalDigits: digits);
    }
    try {
      final parsed = _phoneUtil.parse(digits, selectedCountry.iso2);
      return (country: selectedCountry, nationalDigits: _phoneUtil.getNationalSignificantNumber(parsed));
    } on parser.NumberParseException {
      return (country: selectedCountry, nationalDigits: digits);
    }
  }

  PhoneNumberTextInputFormatterResult _formatNationalDigits({
    required TextEditingValue source,
    required Country country,
    required String nationalDigits,
  }) {
    var formattedText = nationalDigits;
    if (_phoneUtil.getMetadataForRegion(regionCode: country.iso2) != null) {
      final formatter = _phoneUtil.getAsYouTypeFormatter(country.iso2);
      for (final digit in nationalDigits.split('')) {
        formattedText = formatter.inputDigit(digit);
      }
    }

    return PhoneNumberTextInputFormatterResult._(
      textEditingValue: TextEditingValue(
        text: formattedText,
        selection: _mappedSelection(
          source: source,
          formattedText: formattedText,
        ),
        composing: _mappedComposing(
          source: source,
          formattedText: formattedText,
        ),
      ),
      country: country,
      internationalValue: _buildInternationalValue(
        country: country,
        nationalDigits: nationalDigits,
      ),
    );
  }

  TextSelection _mappedSelection({
    required TextEditingValue source,
    required String formattedText,
  }) {
    if (!source.selection.isValid) {
      return const TextSelection.collapsed(offset: -1);
    }
    return TextSelection(
      baseOffset: _offsetAfterDigitCount(
        formattedText,
        _digitCountBeforeOffset(source.text, source.selection.baseOffset),
      ),
      extentOffset: _offsetAfterDigitCount(
        formattedText,
        _digitCountBeforeOffset(source.text, source.selection.extentOffset),
      ),
      affinity: source.selection.affinity,
      isDirectional: source.selection.isDirectional,
    );
  }

  TextRange _mappedComposing({
    required TextEditingValue source,
    required String formattedText,
  }) {
    if (!source.composing.isValid || source.composing.isCollapsed) {
      return TextRange.empty;
    }
    return TextRange(
      start: _offsetAfterDigitCount(
        formattedText,
        _digitCountBeforeOffset(source.text, source.composing.start),
      ),
      end: _offsetAfterDigitCount(
        formattedText,
        _digitCountBeforeOffset(source.text, source.composing.end),
      ),
    );
  }

  static String _buildInternationalValue({
    required Country country,
    required String nationalDigits,
  }) {
    if (nationalDigits.isEmpty) return '';
    return '+${country.callingCode}$nationalDigits';
  }

  static int _nationalDigitLimit(Country country) {
    final lengths = _phoneUtil.getMetadataForRegion(regionCode: country.iso2)?.generalDesc.possibleLength;
    if (lengths == null || lengths.isEmpty) {
      // Catalog territories without metadata retain the international fallback.
      return 15 - country.callingCode!.length;
    }
    return lengths.last;
  }

  static String? _longestCallingCodePrefix(String digits) {
    String? longestMatch;
    for (final country in Country.values) {
      final callingCode = country.callingCode;
      if (callingCode == null || !digits.startsWith(callingCode)) continue;
      if (longestMatch == null || callingCode.length > longestMatch.length) {
        longestMatch = callingCode;
      }
    }
    return longestMatch;
  }

  static String _normalizePhoneInput(String value) {
    final output = StringBuffer();
    var hasDigit = false;
    for (final rune in value.runes) {
      if (rune == 0x2B && !hasDigit && output.isEmpty) {
        output.writeCharCode(rune);
        continue;
      }
      final digit = _decimalDigitValue(rune);
      if (digit == null) continue;
      output.writeCharCode(0x30 + digit);
      hasDigit = true;
    }
    return output.toString();
  }

  static String _extractNormalizedDigits(String value) {
    final output = StringBuffer();
    for (final rune in value.runes) {
      final digit = _decimalDigitValue(rune);
      if (digit != null) output.writeCharCode(0x30 + digit);
    }
    return output.toString();
  }

  static int? _decimalDigitValue(int rune) {
    if (rune >= 0x30 && rune <= 0x39) return rune - 0x30;
    if (rune >= 0x660 && rune <= 0x669) return rune - 0x660;
    if (rune >= 0x6F0 && rune <= 0x6F9) return rune - 0x6F0;
    if (rune >= 0xFF10 && rune <= 0xFF19) return rune - 0xFF10;
    return null;
  }

  static int _digitCountBeforeOffset(String text, int offset) {
    if (offset <= 0) return 0;
    return _extractNormalizedDigits(
      text.substring(0, offset.clamp(0, text.length)),
    ).length;
  }

  static int _offsetAfterDigitCount(String text, int digitCount) {
    if (digitCount == 0) return 0;
    var seen = 0;
    for (var offset = 0; offset < text.length; offset++) {
      if (_decimalDigitValue(text.codeUnitAt(offset)) == null) continue;
      seen++;
      if (seen == digitCount) return offset + 1;
    }
    return text.length;
  }
}
