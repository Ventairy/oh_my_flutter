# Phone number

Use `PhoneNumber` to interact with a phone number throughout an application.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final phoneNumber = PhoneNumber.parse('+1 (202) 555-0123');
```

The input may use spaces, parentheses, dashes, or no visual formatting. It must
begin with `+` and include a country calling code, such as `55` for Brazil or
`1` for the United States and Canada. The national number must have a possible
length for its country, but its prefix does not need to be currently allocated
by a carrier.

For editable and incomplete numbers, see the
[`PhoneNumberTextInputFormatter` guide](text_input_formatters.md#phonenumbertextinputformatter).

## Validate phone-number input

Use `tryParse` when a person may still have incomplete or unsupported input.
It returns `null` instead of throwing when the value cannot become a complete
international phone number:

```dart
const input = '+1 202-555-0123';
final phoneNumber = PhoneNumber.tryParse(input);
final canContinue = phoneNumber?.isValid ?? false;
```

`isValid` checks the complete number against its country's current numbering
plan, including recognized prefix patterns. This stricter check is suitable
for deciding whether an ordinary form can continue.

A valid result does not prove that the number is assigned, active, reachable,
or controlled by the person entering it. Use an SMS or voice verification code
when an application must establish reachability or ownership.

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

`parse` throws a `FormatException` when the value does not begin with `+`, has
no recognizable country calling code, or has a length that is not possible for
that country. Use it when invalid input should be exceptional:

```dart
const input = '+1 202-555-0123';

try {
  final phoneNumber = PhoneNumber.parse(input);
  Text(phoneNumber.toDisplayString());
} on FormatException {
  // Ask for a complete international phone number beginning with +.
}
```

Phone extensions and automatic country inference from the device locale are
not supported.

See the
[`PhoneNumber` API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/PhoneNumber-class.html)
for the complete member contracts.
