import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:meta/meta.dart';
import 'package:oh_my_flutter/src/extensions/string_extension.dart';
import 'package:oh_my_flutter/src/phone_number.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provides a consistent way to interact with a WhatsApp recipient.
///
/// ```dart
/// final whatsapp = Whatsapp('@Ventairy');
///
/// Text(whatsapp.toDisplayString());
/// await whatsapp.chat(message: 'Hello!');
/// ```
///
/// The identifier may be a WhatsApp username or a phone number with a country
/// calling code. Construction throws a [FormatException] when the identifier
/// cannot be resolved to either supported form.
///
/// See the [WhatsApp guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/whatsapp.md)
/// for identifier, message, and fallback behavior.
class Whatsapp {
  /// Creates a WhatsApp recipient from [identifier].
  ///
  /// Usernames may include or omit their leading `@`. Phone numbers may use
  /// common visual formatting but must include a country calling code.
  ///
  /// Throws a [FormatException] when [identifier] is neither a valid username
  /// nor a valid phone number.
  factory Whatsapp(String identifier) {
    return Whatsapp._parse(
      identifier: identifier,
      launcher: launchUrl,
      isWeb: kIsWeb,
    );
  }

  Whatsapp._({
    required this._identifier,
    required this._launcher,
    required this._isWeb,
  });

  factory Whatsapp._parse({
    required String identifier,
    required Future<bool> Function(Uri uri) launcher,
    required bool isWeb,
  }) {
    final trimmedIdentifier = identifier.trim();

    if (trimmedIdentifier.startsWith('@')) {
      return Whatsapp._fromUsername(
        username: trimmedIdentifier.substring(1),
        source: identifier,
        launcher: launcher,
        isWeb: isWeb,
      );
    }

    try {
      final phoneNumber = PhoneNumber(trimmedIdentifier);

      return Whatsapp._(
        identifier: phoneNumber,
        launcher: launcher,
        isWeb: isWeb,
      );
    } on FormatException {
      return Whatsapp._fromUsername(
        username: trimmedIdentifier,
        source: identifier,
        launcher: launcher,
        isWeb: isWeb,
      );
    }
  }

  factory Whatsapp._fromUsername({
    required String username,
    required String source,
    required Future<bool> Function(Uri uri) launcher,
    required bool isWeb,
  }) {
    final normalizedUsername = username.toLowerCase();
    if (!_usernamePattern.hasMatch(normalizedUsername) || normalizedUsername.isDigitsOnly) {
      throw FormatException(
        'A WhatsApp identifier must be a valid phone number with a country '
        'calling code or a username containing 3 to 35 letters, numbers, '
        'periods, or underscores.',
        source,
      );
    }

    return Whatsapp._(
      identifier: normalizedUsername,
      launcher: launcher,
      isWeb: isWeb,
    );
  }

  /// Creates a WhatsApp recipient with a controllable [launcher] for testing.
  ///
  /// Set [isWeb] to `true` to use the web launch path. The [launcher] receives
  /// each computed WhatsApp URI and returns whether the platform accepted it.
  ///
  /// Throws a [FormatException] under the same conditions as [Whatsapp].
  @visibleForTesting
  factory Whatsapp.test(
    String identifier, {
    required Future<bool> Function(Uri uri) launcher,
    bool isWeb = false,
  }) {
    return Whatsapp._parse(
      identifier: identifier,
      launcher: launcher,
      isWeb: isWeb,
    );
  }

  static final _usernamePattern = RegExp(r'^[a-z0-9._]{3,35}$');

  final Object _identifier;
  final Future<bool> Function(Uri uri) _launcher;
  final bool _isWeb;

  bool get _isPhoneNumber => _identifier is PhoneNumber;

  String get _identifierForUri {
    final identifier = _identifier;
    if (identifier is PhoneNumber) return identifier.e164.substring(1);

    return identifier as String;
  }

  /// Returns the recipient identifier formatted for display in an interface.
  ///
  /// Usernames include their leading `@`. Phone numbers follow their country's
  /// international grouping conventions and include the country calling code.
  String toDisplayString() {
    final identifier = _identifier;
    if (identifier is PhoneNumber) return identifier.toDisplayString();

    return '@${identifier as String}';
  }

  /// Opens a WhatsApp chat with this recipient.
  ///
  /// On mobile, this first tries the native WhatsApp URI and falls back to a
  /// `wa.me` link when the native launch returns `false` or throws. On web, it
  /// launches the `wa.me` link directly.
  ///
  /// A non-empty [message] is pre-filled in the chat composer. The returned
  /// Boolean reports whether a destination accepted the launch; it does not
  /// guarantee that the recipient exists or that a message was sent.
  Future<bool> chat({String? message}) {
    if (_isWeb) return _launcher(_buildWebUri(message: message));

    return _launchMobileChat(message: message);
  }

  Future<bool> _launchMobileChat({String? message}) async {
    final queryParameters = <String, String>{
      _isPhoneNumber ? 'phone' : 'username': _identifierForUri,
    };
    if (message != null && message.isNotEmpty) {
      queryParameters['text'] = message;
    }

    try {
      final launched = await _launcher(
        Uri(scheme: 'whatsapp', host: 'send', queryParameters: queryParameters),
      );
      if (launched) return true;
    } catch (_) {
      // The platform could not handle the native WhatsApp URI.
    }

    return _launcher(_buildWebUri(message: message));
  }

  Uri _buildWebUri({String? message}) {
    final hasMessage = message != null && message.isNotEmpty;

    if (_isPhoneNumber) {
      return Uri(
        scheme: 'https',
        host: 'wa.me',
        path: '/$_identifierForUri',
        queryParameters: hasMessage ? <String, String>{'text': message} : null,
      );
    }

    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/',
      queryParameters: <String, String>{
        'username': _identifierForUri,
        if (hasMessage) 'text': message,
      },
    );
  }
}
