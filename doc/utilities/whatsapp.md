# WhatsApp

Use `Whatsapp` to open a chat with an optional pre-filled message.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final launched = await Whatsapp().launchChat(
  number: '+55 (11) 98888-7777',
  message: 'Hello! I would like more information.',
);
```

On non-web platforms, the utility first tries the native WhatsApp URI. If that
launch returns `false` or throws, it tries `https://wa.me` instead. On web, it
uses `wa.me` directly. It returns whether one of those destinations was
accepted; it does not guarantee that the account exists or that a message was
sent.

The public class is named `Whatsapp`. If the final `wa.me` launch fails, its
`false` result is returned, or its exception is propagated to the caller.

The optional message is URI-encoded. A `null` or empty message is omitted.

Always include the country code. Formatting characters are removed, but the
utility does not infer a country code or verify that the number exists. A value
without any digits throws `ArgumentError`. Supply the recipient number only:
digits from extensions or service codes would become part of that recipient.
