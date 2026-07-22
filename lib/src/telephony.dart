import 'package:meta/meta.dart';
import 'package:url_launcher/url_launcher.dart';

/// Interact with phone numbers via the device's telephony capabilities.
///
/// ```dart
/// final telephony = Telephony();
/// await telephony.call(number: '+55 11 98888-7777');
/// ```
///
/// The default constructor wires [launchUrl] from `url_launcher`. Use
/// [Telephony.test] to inject a controllable launcher in tests.
///
/// The utility sanitizes URI syntax but does not validate whether a number
/// exists or infer a missing country code.
class Telephony {
  /// Creates an [Telephony] that delegates to the platform's URI
  /// launcher ([launchUrl] via `url_launcher`).
  factory Telephony() {
    return Telephony._(launchUrl);
  }

  Telephony._(this._launcher);

  /// Creates an [Telephony] with a controllable [launcher] for testing.
  ///
  /// The [launcher] callback receives the computed telephony URI and must
  /// return `true` when the OS accepted the launch.
  @visibleForTesting
  factory Telephony.test({required Future<bool> Function(Uri uri) launcher}) {
    return Telephony._(launcher);
  }

  final Future<bool> Function(Uri uri) _launcher;

  /// Initiates a telephony interaction with [number].
  ///
  /// [number] should be in international format including the country code
  /// (e.g. `+55` for Brazil, `+1` for the US). A leading `+` is preserved
  /// (RFC 3966 global-number prefix); all other non-digit characters are
  /// stripped before composing the `tel:` URI:
  ///
  /// - `"+55 (11) 96923-0546"` -> `tel:+5511969230546`
  /// - `"5511969230546"`       -> `tel:5511969230546`
  /// - `"+1 (415) 555-2671"`   -> `tel:+14155552671`
  ///
  /// A `+` that is not the first non-whitespace character is stripped (it is
  /// only valid as a leading prefix); such input is considered malformed.
  ///
  /// Throws [ArgumentError] when the number contains no digits.
  ///
  /// Returns `true` when the telephony interaction was successfully launched.
  Future<bool> call({required String number}) {
    final trimmed = number.trim();
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      throw ArgumentError.value(
        number,
        'number',
        'Telephony phone number must contain at least one digit. '
            'Received: "$number".',
      );
    }

    final sanitized = hasPlus ? '+$digits' : digits;
    final uri = Uri(scheme: 'tel', path: sanitized);

    return _launcher(uri);
  }
}
