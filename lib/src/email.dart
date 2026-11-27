import 'package:meta/meta.dart';
import 'package:oh_my_flutter/src/extensions/string_extension.dart';
import 'package:url_launcher/url_launcher.dart';

/// Use an email address throughout your app.
///
/// See the [email guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/email.md).
class Email {
  /// Reads an address using the same rules as [StringExtension.isValidEmail].
  ///
  /// Throws [FormatException] if [value] is invalid.
  factory parse(String value) => Email._parse(value, launcher: launchUrl);

  new _({required this.address, required this._launcher});

  factory _parse(String value, {required Future<bool> Function(Uri) launcher}) {
    if (!value.isValidEmail) {
      throw FormatException('Expected a plain email address.', value);
    }

    return Email._(address: value.trim(), launcher: launcher);
  }

  /// Creates an address with a controllable mail app [launcher] for tests.
  @visibleForTesting
  factory test(String value, {required Future<bool> Function(Uri) launcher}) => Email._parse(value, launcher: launcher);

  /// Returns the parsed address, or `null` if [value] is invalid.
  static Email? tryParse(String value) {
    try {
      return Email.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// The address as entered, with surrounding whitespace removed.
  final String address;

  final Future<bool> Function(Uri) _launcher;

  /// Opens a draft addressed to this email with an optional [body] and [subject].
  ///
  /// Returns whether the platform accepted the request to open the draft.
  Future<bool> send({String? body, String? subject}) {
    final query = [
      if (subject != null) 'subject=${Uri.encodeComponent(subject)}',
      if (body != null) 'body=${Uri.encodeComponent(body)}',
    ].join('&');
    return _launcher(Uri(scheme: 'mailto', path: address, query: query.isEmpty ? null : query));
  }
}
