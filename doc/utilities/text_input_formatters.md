# Text input formatters

Use text input formatters to shape editable values while a person types or
pastes. Pass them to your text field's `inputFormatters`. Assigning a controller
value programmatically does not apply the field's formatters automatically.

```dart
import 'package:flutter/services.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
```

## HandleTextInputFormatter

Use `HandleTextInputFormatter` to enter an account handle without an `@` prefix
or whitespace. For example, pasting ` @Some.Name_42 ` produces `Some.Name_42`.
Case, Unicode, and other characters are preserved.

```dart
const List<TextInputFormatter> handleFormatters = [HandleTextInputFormatter()];
```

Pass `handleFormatters` to your text field's `inputFormatters`. Display a fixed
`@` separately if your interface needs one; it is not part of the entered value.

Selection follows the retained characters. Text being composed by an input
method stays untouched until the person commits it.

Supply controller values in the bare-handle format.
Your application owns service-specific validation and length limits. Profile
URLs are not converted into handles.

See the [generated API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/HandleTextInputFormatter-class.html)
for the complete contract.

## PhoneNumberTextInputFormatter

Use `PhoneNumberTextInputFormatter` while a person is entering a phone number.
It formats partial national text and returns its country and international
value without requiring the number to be complete.

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
```

Pass `inputFormatter` to the field's `inputFormatters`. Read `internationalValue`
in its `onChanged` callback. The visible field contains nationally formatted
text. `internationalValue` is empty when the field has no national digits;
otherwise it contains `+`, the
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

### Change the selected country

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

Use [`PhoneNumber`](phone_number.md#validate-phone-number-input) to validate a
complete international value before continuing.

See the [generated API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/PhoneNumberTextInputFormatter-class.html)
for the complete contract.
