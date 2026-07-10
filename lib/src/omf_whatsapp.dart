import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:meta/meta.dart';
import 'package:url_launcher/url_launcher.dart';

/// Interact with WhatsApp.
///
/// ```dart
/// final whatsapp = OmfWhatsapp();
///
/// await whatsapp.launchChat(
///   number: '+55 11 98888-7777',
///   message: 'Olá, encontrei você no Cataquí!',
/// );
/// ```
///
/// The default constructor wires [launchUrl] from `url_launcher`. Use
/// [OmfWhatsapp.test] to inject a controllable launcher in tests.
class OmfWhatsapp {
  /// Creates an [OmfWhatsapp] that delegates to the platform's deeplink
  /// launcher ([launchUrl] via `url_launcher`).
  factory OmfWhatsapp() {
    return OmfWhatsapp._(launchUrl, isWeb: kIsWeb);
  }

  OmfWhatsapp._(this._launcher, {this._isWeb = false});

  /// Creates an [OmfWhatsapp] with a controllable params for testing.
  ///
  /// The [launcher] callback receives the computed WhatsApp URI and must
  /// return `true` when the OS accepted the launch.
  ///
  /// Set [isWeb] to `true` to simulate the web platform path
  @visibleForTesting
  factory OmfWhatsapp.test({required Future<bool> Function(Uri uri) launcher, bool isWeb = false}) {
    return OmfWhatsapp._(launcher, isWeb: isWeb);
  }

  final Future<bool> Function(Uri uri) _launcher;

  final bool _isWeb;

  /// Opens a WhatsApp chat with [number] and an optional pre-filled
  /// [message].
  ///
  /// On **mobile** this first attempts the native `whatsapp://` scheme to
  /// open WhatsApp directly. If WhatsApp is not installed, it falls back to
  /// `https://wa.me/<number>` (which opens the browser and redirects to
  /// WhatsApp). On **web** it always uses `https://wa.me/<number>`.
  ///
  /// [number] must be in international format, including the country code
  /// (e.g. `+55` for Brazil, `+1` for the US). Any non-digit characters
  /// are stripped before composing the deeplink, so common human formats
  /// are accepted:
  ///
  /// - `"+55 (11) 96923-0546"` -> `https://wa.me/5511969230546`
  /// - `"5511969230546"`       -> `https://wa.me/5511969230546`
  /// - `"+1 (415) 555-2671"`   -> `https://wa.me/14155552671`
  ///
  /// Passing a local-format number (no country code) yields a misrouted
  /// link — always include the country code.
  ///
  /// Throws [ArgumentError] when the result contains no digits.
  ///
  /// Returns `true` when WhatsApp was successfully launched.
  Future<bool> launchChat({required String number, String? message}) {
    final digits = number.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      throw ArgumentError.value(
        number,
        'number',
        'WhatsApp phone number must contain at least one digit. '
            'Received: "$number".',
      );
    }

    if (_isWeb) return _launcher(_buildWaMeUri(digits: digits, message: message));
    return _launchMobileChat(digits: digits, message: message);
  }

  Future<bool> _launchMobileChat({required String digits, String? message}) async {
    final params = <String, String>{'phone': digits};
    if (message != null && message.isNotEmpty) params['text'] = message;

    final launched = await _launcher(Uri(scheme: 'whatsapp', host: 'send', queryParameters: params));
    if (launched) return true;

    return _launcher(_buildWaMeUri(digits: digits, message: message));
  }

  Uri _buildWaMeUri({required String digits, String? message}) {
    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$digits',
      queryParameters: (message != null && message.isNotEmpty) ? <String, String>{'text': message} : null,
    );
  }
}
