import 'package:oh_my_flutter/src/phone_number.dart';

/// Utilities for [String] values.
///
/// See the [string classification guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/extensions/string.md)
/// for usage examples and value classifications.
extension StringExtension on String {
  static final _emailPattern = RegExp(
    r"^(?:[A-Za-z0-9_'+\-]+\.)*[A-Za-z0-9_'+\-]*[A-Za-z0-9_+-]@(?:[A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$",
  );
  static final _telegramUsernamePattern = RegExp(r'^[a-z][a-z0-9_]{2,30}[a-z0-9]$', caseSensitive: false);
  static final _instagramUsernamePattern = RegExp(
    r'^(?!\.)(?!.*\.\.)(?!.*\.$)[a-z0-9._]{1,30}$',
    caseSensitive: false,
  );
  static final _whatsappUsernamePattern = RegExp(
    r'^(?!www\.)(?!\.)(?!.*\.\.)(?!.*\.$)'
    r'(?!.*\.(?:com|org|net|int|edu|gov|mil|arpa|html|htm|txt|xml)$)'
    r'(?=.*[a-z])[a-z0-9._]{3,35}$',
    caseSensitive: false,
  );

  /// Whether this non-empty value contains only ASCII digits from `0` to `9`.
  bool get isDigitsOnly {
    if (isEmpty) return false;

    for (final codeUnit in codeUnits) {
      if (codeUnit < 0x30 || codeUnit > 0x39) return false;
    }

    return true;
  }

  /// Checks an email address before submitting a form.
  ///
  /// Ignores surrounding whitespace and accepts common, unquoted ASCII
  /// addresses up to 320 characters. The domain must contain a period and end
  /// with at least two ASCII letters. Leading, trailing, or consecutive periods
  /// in the local part, internal whitespace, and display names are rejected.
  /// This checks format without confirming that the mailbox exists.
  bool get isValidEmail {
    final value = trim();
    return value.length <= 320 && _emailPattern.hasMatch(value);
  }

  /// Checks whether a complete international phone number matches its country's
  /// numbering plan.
  ///
  /// Requires a leading `+` and country calling code. Surrounding whitespace
  /// and common phone formatting are accepted, as with [PhoneNumber.tryParse].
  /// This does not confirm that the number is assigned or reachable.
  bool get isValidPhoneNumber => PhoneNumber.tryParse(this)?.isValid ?? false;

  /// Checks the format of a Telegram contact username.
  ///
  /// Ignores surrounding whitespace and accepts one optional leading `@`.
  /// The username must contain 4 to 32 ASCII letters, digits, or underscores,
  /// start with a letter, and end with a letter or digit. Case is ignored.
  /// Four-character names accommodate collectible usernames. Reserved action
  /// paths, such as `share` and `joinchat`, are rejected. This does not check
  /// account existence or availability.
  bool get isValidTelegramUsername {
    final username = _username;
    return _telegramUsernamePattern.hasMatch(username) &&
        !const {
          'addemoji',
          'addlist',
          'addstickers',
          'addstyle',
          'addtheme',
          'auction',
          'auth',
          'boost',
          'call',
          'confirmphone',
          'contact',
          'giftcode',
          'invoice',
          'joinchat',
          'login',
          'nft',
          'proxy',
          'setlanguage',
          'share',
          'socks',
        }.contains(username.toLowerCase());
  }

  /// Checks the format of an Instagram contact username.
  ///
  /// Ignores surrounding whitespace and accepts one optional leading `@`.
  /// The username must contain 1 to 30 ASCII letters, digits, periods, or
  /// underscores, without leading, trailing, or consecutive periods. Case is
  /// ignored. Reserved navigation paths, such as `accounts`, `direct`, and
  /// `stories`, are rejected. This does not check account existence or
  /// availability.
  bool get isValidInstagramUsername {
    final username = _username;
    return _instagramUsernamePattern.hasMatch(username) &&
        !const {
          'p',
          'reel',
          'reels',
          'tv',
          'stories',
          'explore',
          'direct',
          'accounts',
        }.contains(username.toLowerCase());
  }

  /// Checks the format of a WhatsApp contact username.
  ///
  /// Ignores surrounding whitespace and accepts one optional leading `@`.
  /// The username must contain 3 to 35 ASCII letters, digits, periods, or
  /// underscores, including at least one letter. Case is ignored.
  /// Leading, trailing, or consecutive periods, a `www.` prefix, and these
  /// suffixes are rejected: `.com`, `.org`, `.net`, `.int`, `.edu`, `.gov`,
  /// `.mil`, `.arpa`, `.html`, `.htm`, `.txt`, and `.xml`.
  /// This does not check account existence, availability, or restricted words.
  bool get isValidWhatsappUsername => _whatsappUsernamePattern.hasMatch(_username);

  String get _username {
    final value = trim();
    return value.startsWith('@') ? value.substring(1) : value;
  }
}
