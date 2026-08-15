# Telephony

Use `Telephony` when an application should ask the platform to start a phone
call.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final launched = await Telephony().call(
  number: '+55 (11) 98888-7777',
);
```

The utility trims surrounding whitespace, preserves `+` only when it is the
first character after trimming, removes every other non-digit character, and
passes a `tel:` URI to the platform. The operating system decides whether to
show a dialer or another telephony interface. The returned Boolean says only
whether the platform accepted the URI; it does not guarantee that a call was
connected.

Always include the country code. `Telephony` sanitizes URI input but does not
infer a country code or verify that a phone number exists. A value without any
digits throws `ArgumentError`. Platform launch failures are forwarded to the
caller.
