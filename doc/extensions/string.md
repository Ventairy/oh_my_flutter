# String classification

`StringExtension` adds convenient operations to Dart strings.

## Values containing only digits

Use `isDigitsOnly` when a non-empty value must contain only the ASCII digits
from `0` to `9`:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final isNumericIdentifier = '12345'.isDigitsOnly;
// true
```

The getter returns `false` for an empty string and for values containing
letters, whitespace, signs, decimal separators, or other characters.

## Validate contact details

Use the validation getters to check contact details before submitting a form.
They run locally, ignore surrounding whitespace, and leave the original string
unchanged. Empty or malformed input returns `false`.

These checks describe accepted formats. They do not confirm that an account
exists, that a username is available, or that a number or mailbox is reachable.
Known platform-reserved action and navigation paths are rejected for Telegram
and Instagram usernames. Applications can apply additional rules for their own
contact flows.

### Email addresses

Use `isValidEmail` for common ASCII email addresses:

```dart
final accepted = ' Poster.Name+jobs@EXAMPLE.COM '.isValidEmail;
// true

final malformed = 'poster..name@example.com'.isValidEmail;
// false
```

Addresses can contain up to 320 characters after trimming. They require an
unquoted ASCII local part and a dotted domain whose final suffix contains at
least two ASCII letters. Leading, trailing, or consecutive periods in the
local part, internal whitespace, display names, `mailto:` links, quoted local
parts, and internationalized addresses are rejected.

### International phone numbers

Use `isValidPhoneNumber` when a number must match its country's numbering plan:

```dart
final accepted = ' +1 (202) 555-0123 '.isValidPhoneNumber;
// true

final incomplete = '2025550123'.isValidPhoneNumber;
// false
```

Numbers require a leading `+` and country calling code. Common visual formatting
is accepted. A number with a possible length can still return `false` when its
digits do not match the numbering plan.

When you also need the parsed number for display, saving, or calling, use
`PhoneNumber.tryParse` and inspect its `isValid` property directly. This avoids
parsing the same value again.

### Telegram usernames

Use `isValidTelegramUsername` for a bare username or one beginning with `@`:

```dart
final accepted = ' @Poster_123 '.isValidTelegramUsername;
// true

final malformed = 'poster.name'.isValidTelegramUsername;
// false
```

Usernames contain 4 to 32 ASCII letters, digits, or underscores, start with a
letter, and end with a letter or digit. Case is ignored. Four-character names
accommodate collectible contact usernames; passing this check does not mean a
name can be registered as a new basic Telegram username. Reserved action paths,
such as `share` and `joinchat`, are rejected.

### Instagram usernames

Use `isValidInstagramUsername` to check an Instagram handle:

```dart
final accepted = '@Poster.Name'.isValidInstagramUsername;
// true

final malformed = 'poster..name'.isValidInstagramUsername;
// false
```

Usernames contain 1 to 30 ASCII letters, digits, periods, or underscores. Case
is ignored. Leading, trailing, or consecutive periods are rejected. A single
leading `@` is optional. Reserved navigation paths, such as `accounts`, `direct`,
and `stories`, are rejected.

### WhatsApp usernames

Use `isValidWhatsappUsername` to check a WhatsApp handle:

```dart
final accepted = '@Poster.Name'.isValidWhatsappUsername;
// true

final malformed = '@www.poster'.isValidWhatsappUsername;
// false
```

Usernames contain 3 to 35 ASCII letters, digits, periods, or underscores and
include at least one letter. Case is ignored, and a single leading `@` is
optional. Leading, trailing, or consecutive periods and a `www.` prefix are
rejected. These suffixes are also rejected: `.com`, `.org`, `.net`, `.int`,
`.edu`, `.gov`, `.mil`, `.arpa`, `.html`, `.htm`, `.txt`, and `.xml`.

All username getters reject internal whitespace, multiple `@` prefixes, and
profile links. Supply the username itself, such as `@poster`, rather than a
link such as `https://instagram.com/poster`.

See the
[generated API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/StringExtension.html)
for the complete member contract.
