# Email

Use `Email` to work with a person's email address throughout your app.

## Parse an address

`Email.parse` accepts the same plain ASCII addresses as
[`String.isValidEmail`](../extensions/string.md). The `address` property keeps
the original capitalization and removes surrounding whitespace.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final support = Email.parse(' Support+app@example.com ');
```

Invalid input such as a display name or a `mailto:` link throws a
`FormatException`. Use `Email.tryParse(input)` for an editable form. It returns
`null` while the input is incomplete or invalid.

## Open a draft

Call `support.send()` to open a draft addressed to support. Pass `body`,
`subject`, or both to fill in the draft.

```dart
final opened = await support.send(
  body: 'How can I change my delivery address?',
  subject: 'Delivery question',
);
```

A result of `true` means the platform accepted the request to open the draft.
The user reviews and sends the message in their mail app. A platform can
return `false` or report a launch error if it cannot open the draft.

See the [`Email` API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/Email-class.html)
for the complete member contracts.
