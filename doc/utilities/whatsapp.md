# WhatsApp

Use `Whatsapp` to interact with a WhatsApp recipient throughout an
application.

## Identify a recipient

Create a `Whatsapp` with either a username or phone number:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final usernameRecipient = Whatsapp('@Ventairy');
final phoneRecipient = Whatsapp('+1 (202) 555-0123');
```

Usernames may include or omit their leading `@`. They are normalized to
lowercase and must contain 3 to 35 letters, numbers, periods, or underscores.
A username cannot contain only numbers.

Phone numbers may use common visual formatting but must include a country
calling code. They are checked against the numbering metadata used by
`PhoneNumber`.

Construction throws a `FormatException` when the identifier is neither a
valid username nor a valid phone number.

## Display the identifier

Use `toDisplayString` to show the recipient clearly in an interface:

```dart
Text(usernameRecipient.toDisplayString());
// @ventairy

Text(phoneRecipient.toDisplayString());
// +1 202-555-0123
```

Usernames include their leading `@`. Phone numbers follow their country's
international grouping conventions and include the country calling code.

## Open a chat

Use `chat` to open a conversation. A non-empty message is placed in the chat
composer for the user to review and send:

```dart
final launched = await usernameRecipient.chat(
  message: 'Hello! I would like more information.',
);
```

On mobile, the package first tries the native WhatsApp URI. If that launch
returns `false` or throws, it tries the matching `wa.me` link. On web, it uses
the `wa.me` link directly. The returned Boolean reports whether a destination
accepted the launch; it does not guarantee that the recipient exists or that a
message was sent.

A `null` or empty message is omitted. Message text is URI-encoded.

## Username availability

WhatsApp usernames are being introduced gradually. A recipient with a username
key may require the user to enter that key inside WhatsApp before starting a
first conversation. This package does not verify accounts or manage username
keys.

See WhatsApp's guides to
[contacting someone by username](https://faq.whatsapp.com/1561101675623754/)
and
[username rules](https://faq.whatsapp.com/2535820043482794/)
for current service availability and restrictions.

See the
[`Whatsapp` API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/Whatsapp-class.html)
for the complete member contracts.
