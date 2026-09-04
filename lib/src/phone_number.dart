import 'package:meta/meta.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as parser;
import 'package:url_launcher/url_launcher.dart';

/// Provides a consistent way to interact with a phone number.
///
/// ```dart
/// final phoneNumber = PhoneNumber('+1 202-555-0123');
///
/// Text(phoneNumber.toDisplayString());
/// await phoneNumber.call();
/// ```
///
/// The input must include a country calling code, with or without a leading
/// `+`. Common spacing and punctuation are accepted. Construction throws a
/// [FormatException] when the input cannot be resolved to a valid number in
/// the current numbering metadata.
///
/// Metadata validation confirms that a value matches a numbering plan. It does
/// not confirm that the number exists, is connected, or can receive calls.
///
/// See the [phone number guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/phone_number.md)
/// for formatting and platform behavior.
class PhoneNumber {
  /// Creates a phone number from [value].
  ///
  /// [value] may contain common human-readable formatting and may omit the
  /// leading `+`, but it must include a country calling code.
  ///
  /// Throws a [FormatException] when [value] cannot be resolved to a valid
  /// phone number with a country calling code.
  factory PhoneNumber(String value) {
    return PhoneNumber._parse(value: value, launcher: launchUrl);
  }

  PhoneNumber._({required this._parsed, required this._launcher});

  factory PhoneNumber._parse({
    required String value,
    required Future<bool> Function(Uri uri) launcher,
  }) {
    try {
      final parsed = parser.PhoneNumber.parse(value);
      if (!parsed.isValid()) throw FormatException(_invalidMessage, value);

      return PhoneNumber._(parsed: parsed, launcher: launcher);
    } on parser.PhoneNumberException {
      throw FormatException(_invalidMessage, value);
    }
  }

  /// Creates a phone number with a controllable [launcher] for testing.
  ///
  /// The [launcher] receives the canonical international `tel:` URI and
  /// returns `true` when the operating system accepts the launch.
  ///
  /// Throws a [FormatException] under the same conditions as [PhoneNumber].
  @visibleForTesting
  factory PhoneNumber.test(
    String value, {
    required Future<bool> Function(Uri uri) launcher,
  }) {
    return PhoneNumber._parse(value: value, launcher: launcher);
  }

  static const _invalidMessage =
      'A phone number must include a country calling code and match its '
      'current numbering plan.';

  final parser.PhoneNumber _parsed;
  final Future<bool> Function(Uri uri) _launcher;

  /// Returns the canonical E.164 value for use by application code.
  ///
  /// The result contains a leading `+`, the country calling code, and the
  /// national number without display formatting.
  String get e164 => _parsed.international;

  /// Returns the phone number formatted for display in an interface.
  ///
  /// The result follows the number's international grouping rules. By
  /// default, it includes the `+` and country calling code:
  ///
  /// ```dart
  /// PhoneNumber('+12025550123').toDisplayString();
  /// // +1 202-555-0123
  /// ```
  ///
  /// Set [includeCountryCode] to `false` to omit only the `+` and country
  /// calling code while retaining international grouping. This does not
  /// convert the result to the country's domestic dialing format.
  String toDisplayString({bool includeCountryCode = true}) {
    final nationalNumber = _parsed.formatNsn(
      format: parser.NsnFormat.international,
    );

    if (!includeCountryCode) return nationalNumber;

    return '+${_parsed.countryCode} $nationalNumber';
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
