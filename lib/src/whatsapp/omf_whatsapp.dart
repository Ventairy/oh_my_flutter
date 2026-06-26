import 'package:meta/meta.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp chats programmatically via deeplink.
///
/// ```dart
/// final whatsapp = OmfWhatsapp();
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
    return OmfWhatsapp._(launchUrl);
  }

  OmfWhatsapp._(this._launcher);

  /// Creates an [OmfWhatsapp] with a controllable [launcher] for testing.
  ///
  /// The [launcher] callback receives the computed WhatsApp URI and must
  /// return `true` when the OS accepted the launch.
  @visibleForTesting
  factory OmfWhatsapp.test({required Future<bool> Function(Uri uri) launcher}) {
    return OmfWhatsapp._(launcher);
  }

  final Future<bool> Function(Uri uri) _launcher;

  /// Opens a WhatsApp chat with [number] and an optional pre-filled
  /// [message].
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

    final uri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$digits',
      queryParameters: (message != null && message.isNotEmpty) ? <String, String>{'text': message} : null,
    );

    return _launcher(uri);
  }
}
