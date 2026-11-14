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
/// cannot be resolved to either supported form. Accepted phone identifiers
/// have a possible length for their country, but their prefixes do not need to
/// be allocated by a carrier.
///
/// See the [WhatsApp guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/whatsapp.md)
/// for identifier, message, and fallback behavior.
class Whatsapp {
  /// Creates a WhatsApp recipient from [identifier].
  ///
  /// Usernames must satisfy [StringExtension.isValidWhatsappUsername] and may
  /// include or omit their leading `@`. Phone numbers may use
  /// common visual formatting but must include a country calling code and have
  /// a possible length for their country.
  ///
  /// Throws a [FormatException] when [identifier] is neither a valid username
  /// nor a complete international phone identifier.
  factory(String identifier) {
    return Whatsapp._parse(
      identifier: identifier,
      launcher: launchUrl,
      isWeb: kIsWeb,
    );
  }

  new _({
    required this._identifier,
    required this._launcher,
    required this._isWeb,
  });

  factory _parse({
    required String identifier,
    required Future<bool> Function(Uri uri) launcher,
    required bool isWeb,
  }) {
    final trimmedIdentifier = identifier.trim();

    if (trimmedIdentifier.startsWith('@')) {
      return Whatsapp._fromUsername(
        username: trimmedIdentifier,
        source: identifier,
        launcher: launcher,
        isWeb: isWeb,
      );
    }

    final phoneNumber = PhoneNumber.tryParse(
      trimmedIdentifier.startsWith('+') ? trimmedIdentifier : '+$trimmedIdentifier',
    );
    if (phoneNumber != null) {
      return Whatsapp._(
        identifier: phoneNumber,
        launcher: launcher,
        isWeb: isWeb,
      );
    }

    return Whatsapp._fromUsername(
      username: trimmedIdentifier,
      source: identifier,
      launcher: launcher,
      isWeb: isWeb,
    );
  }

  factory _fromUsername({
    required String username,
    required String source,
    required Future<bool> Function(Uri uri) launcher,
    required bool isWeb,
  }) {
    if (!username.isValidWhatsappUsername) {
      throw FormatException(
        'A WhatsApp identifier must be a valid phone number with a country '
        'calling code or a username containing 3 to 35 ASCII letters, digits, '
        'periods, or underscores, including at least one letter. Usernames '
        'cannot have leading, trailing, or consecutive periods, start with '
        'www., or end with a reserved domain or file suffix.',
        source,
      );
    }
    final normalizedUsername = (username.startsWith('@') ? username.substring(1) : username).toLowerCase();

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
  factory test(
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

  static String _encodeQuery(Map<String, String> parameters) => parameters.entries
      .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
      .join('&');

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
        Uri(scheme: 'whatsapp', host: 'send', query: _encodeQuery(queryParameters)),
      );
      if (launched) return true;
    } catch (_) {
      // The platform could not handle the native WhatsApp URI.
    }

    return await _launcher(_buildWebUri(message: message));
  }

  Uri _buildWebUri({String? message}) {
    final hasMessage = message != null && message.isNotEmpty;

    if (_isPhoneNumber) {
      return Uri(
        scheme: 'https',
        host: 'wa.me',
        path: '/$_identifierForUri',
        query: hasMessage ? _encodeQuery({'text': message}) : null,
      );
    }

    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/',
      query: _encodeQuery({
        'username': _identifierForUri,
        if (hasMessage) 'text': message,
      }),
    );
  }
}
