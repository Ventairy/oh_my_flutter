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

Use `PhoneNumberTextInputFormatter` while a person is still entering a number.
It formats partial national text and returns its country and international
value without requiring the number to be complete.

## Format phone-number input

Create a formatter for the selected country. A field that permits pasted
international values should retain the complete formatting result and recreate
the formatter when that result resolves another country:

```dart
var formatter = PhoneNumberTextInputFormatter(
  country: Country.brazil,
);
var internationalValue = '';

final inputFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
  final result = formatter.formatEditUpdateWithResult(oldValue, newValue);
  formatter = PhoneNumberTextInputFormatter(country: result.country);
  internationalValue = result.internationalValue;
  return result.textEditingValue;
});

TextField(
  keyboardType: TextInputType.phone,
  inputFormatters: [inputFormatter],
  onChanged: (_) => usePhoneNumber(internationalValue),
);
```

The visible field contains nationally formatted text. `internationalValue` is
empty when the field has no national digits; otherwise it contains `+`, the
resolved calling code, and the unformatted national digits. Partial numbers
remain available so an application can retain or validate work in progress.

When the country catalog supplies a calling code without national formatting
metadata, the formatter retains the entered digits without adding punctuation.
The international value and country selection remain available.

An explicit international paste beginning with `+` returns the resolved country.
If multiple countries share the calling code, the configured country remains
selected when it is compatible. Unrecognized international values and digits
beyond the country's supported length are rejected.

When `PhoneNumberTextInputFormatter` is placed directly in `inputFormatters`,
it keeps its configured country fixed and rejects an international value that
would select another country. Use `formatEditUpdateWithResult` as shown above
when the field can change its country from entered text.

When a country picker changes the selection, create a formatter for that country
and reformat the current national field value:

```dart
formatter = PhoneNumberTextInputFormatter(
  country: Country.unitedStates,
);
final result = formatter.formatNationalValue(controller.value);
controller.value = result.textEditingValue;
internationalValue = result.internationalValue;
```

Changing country preserves the national digits and maps the selection to the
reformatted text, even when the existing digits exceed the newly selected
country's normal maximum. Further additions remain limited. Countries without a
calling code cannot be used.

## Validate phone-number input

Use `tryParse` when a person may still have incomplete or unsupported input.
It returns `null` instead of throwing when the value cannot become a complete
international phone number:

```dart
final phoneNumber = PhoneNumber.tryParse(internationalValue);
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
