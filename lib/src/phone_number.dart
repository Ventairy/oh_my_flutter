import 'package:dlibphonenumber/dlibphonenumber.dart' as parser;
import 'package:meta/meta.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provides a consistent way to interact with a phone number.
///
/// ```dart
/// final phoneNumber = PhoneNumber.parse('+1 202-555-0123');
///
/// Text(phoneNumber.toDisplayString());
/// await phoneNumber.call();
/// ```
///
/// The input must begin with `+` and include a country calling code. Common
/// spacing and punctuation are accepted. Parsing requires a complete number
/// with a possible length for its country.
///
/// Use [isValid] to check whether the number also matches its country's current
/// numbering plan. Neither successful parsing nor validation confirms that the
/// number exists or can receive calls.
///
/// See the [phone number guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/phone_number.md)
/// for formatting and platform behavior.
class PhoneNumber {
  /// Parses a complete international phone number from [value].
  ///
  /// [value] may contain common human-readable formatting, but it must begin
  /// with `+`, include a country calling code, and have a possible length for
  /// its country.
  ///
  /// Throws a [FormatException] when [value] cannot be resolved to a supported
  /// complete phone number.
  factory parse(String value) {
    return PhoneNumber._parse(value: value, launcher: launchUrl);
  }

  new _({required this._parsed, required this._launcher});

  factory _parse({
    required String value,
    required Future<bool> Function(Uri uri) launcher,
  }) {
    try {
      final input = value.trim();
      // Keep identifiers and extensions out of the numeric phone API.
      if (!input.startsWith('+') || RegExp('[a-zA-Z]').hasMatch(input)) {
        throw FormatException(_invalidMessage, value);
      }
      final parsed = _phoneUtil.parse(input, 'ZZ');
      if (_phoneUtil.isPossibleNumberWithReason(parsed) != parser.ValidationResult.isPossible) {
        throw FormatException(_invalidMessage, value);
      }

      return PhoneNumber._(parsed: parsed, launcher: launcher);
    } on parser.NumberParseException {
      throw FormatException(_invalidMessage, value);
    }
  }

  /// Creates a phone number with a controllable [launcher] for testing.
  ///
  /// The [launcher] receives the canonical international `tel:` URI and
  /// returns `true` when the operating system accepts the launch.
  ///
  /// Throws a [FormatException] under the same conditions as
  /// [PhoneNumber.parse].
  @visibleForTesting
  factory test(
    String value, {
    required Future<bool> Function(Uri uri) launcher,
  }) {
    return PhoneNumber._parse(value: value, launcher: launcher);
  }

  /// Tries to parse a complete international phone number from [value].
  ///
  /// Returns `null` under the same conditions that [PhoneNumber.parse] throws a
  /// [FormatException].
  static PhoneNumber? tryParse(String value) {
    try {
      return PhoneNumber.parse(value);
    } on FormatException {
      return null;
    }
  }

  static const _invalidMessage =
      'A phone number must begin with +, include a country calling code, and '
      'have a possible length for that country.';

  static final parser.PhoneNumberUtil _phoneUtil = parser.PhoneNumberUtil.instance;

  final parser.PhoneNumber _parsed;
  final Future<bool> Function(Uri uri) _launcher;

  /// Whether this number matches its country's current numbering plan.
  ///
  /// A valid result does not confirm that the number is assigned, reachable,
  /// or controlled by a particular person. Use SMS or voice verification when
  /// an application must establish reachability or ownership.
  bool get isValid => _phoneUtil.isValidNumber(_parsed);

  /// Returns the canonical E.164 value for use by application code.
  ///
  /// The result contains a leading `+`, the country calling code, and the
  /// national number without display formatting.
  String get e164 => _phoneUtil.format(_parsed, parser.PhoneNumberFormat.e164);

  /// Returns the phone number formatted for display in an interface.
  ///
  /// The result follows the number's international grouping rules. By
  /// default, it includes the `+` and country calling code:
  ///
  /// ```dart
  /// PhoneNumber.parse('+12025550123').toDisplayString();
  /// // +1 202-555-0123
  /// ```
  ///
  /// Set [includeCountryCode] to `false` to omit only the `+` and country
  /// calling code while retaining international grouping. This does not
  /// convert the result to the country's domestic dialing format.
  String toDisplayString({bool includeCountryCode = true}) {
    final international = _phoneUtil.format(_parsed, parser.PhoneNumberFormat.international);
    if (includeCountryCode) return international;
    return international.substring('+${_parsed.countryCode}'.length).trimLeft();
  }

  /// Starts a phone call to this number using the platform's phone app.
  ///
  /// The platform receives the canonical number in a `tel:` URI and may ask
  /// the user to confirm the call. The returned Boolean reports whether the
  /// platform accepted the request; it does not guarantee that the call was
  /// connected.
  Future<bool> call() {
    return _launcher(Uri(scheme: 'tel', path: e164));
  }
}
