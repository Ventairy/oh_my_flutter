# Phone number

Use `PhoneNumber` to interact with a phone number throughout an application.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final phoneNumber = PhoneNumber('+1 (202) 555-0123');
```

The input may use spaces, parentheses, dashes, or no visual formatting. It must
include a country calling code, such as `55` for Brazil or `1` for the United
States and Canada. The leading `+` is optional.

## Display a phone number

Use `toDisplayString` to produce text that follows the phone number's country
conventions:

```dart
Text(phoneNumber.toDisplayString());
// +1 202-555-0123
```

The country calling code is included by default. It can be omitted when the
surrounding interface already makes the country clear:

```dart
Text(
  phoneNumber.toDisplayString(includeCountryCode: false),
);
// 202-555-0123
```

Omitting the country code does not change the remaining text to a domestic
dialing form. It retains the grouping used for international display.

## Use a phone number in code

Use `e164` when application code needs a canonical value instead of text made
for display:

```dart
final value = phoneNumber.e164;
// +12025550123
```

The value always contains a leading `+`, the country calling code, and the
national number without spaces or punctuation.

## Call a phone number

Use `call` to ask the platform to open its phone interface with the number:

```dart
final launched = await phoneNumber.call();
```

The returned Boolean says only whether the platform accepted the request. It
does not guarantee that a call was connected.

## Handle invalid input

Construction throws a `FormatException` when the value has no recognizable
country calling code or does not match the country's current numbering plan.

```dart
const input = '+1 202-555-0123';

try {
  final phoneNumber = PhoneNumber(input);
  Text(phoneNumber.toDisplayString());
} on FormatException {
  // Ask for a complete phone number with a country calling code.
}
```

A value matching a numbering plan is not proof that the number exists, is
connected, or belongs to a particular person. Phone extensions and automatic
country inference from the device locale are not supported.

See the
[`PhoneNumber` API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/PhoneNumber-class.html)
for the complete member contracts.
