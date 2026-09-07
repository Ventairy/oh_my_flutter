# Country

Use `Country` to identify countries and territories consistently throughout
your application.

```dart
import 'dart:ui';

import 'package:oh_my_flutter/oh_my_flutter.dart';

const country = Country.brazil;
```

## Read ISO identifiers

`iso2` returns a two-letter uppercase identifier and `iso3` returns a
three-letter uppercase identifier. Both are non-nullable:

```dart
final shortCode = country.iso2; // BR
final longCode = country.iso3; // BRA
```

Save one of these codes when storing a country. Enum indexes and Dart member
names are not interchange identifiers. `Country.values` provides all 252
supported countries and territories: the 249 officially assigned ISO 3166-1
entries plus Ascension Island, Tristan da Cunha, and Kosovo.

Most identifiers are officially assigned ISO codes. The following entries use
established reserved or Unicode CLDR mappings instead:

| Country                   | `iso2` | `iso3` |
| ------------------------- | ------ | ------ |
| `Country.ascensionIsland` | `AC`   | `ASC`  |
| `Country.tristanDaCunha`  | `TA`   | `TAA`  |
| `Country.kosovo`          | `XK`   | `XKK`  |

These are established mappings, not identifiers invented by this package.
They round-trip through the lookup methods, but an external service requiring
only officially assigned ISO codes may reject them. Check the receiving
service's accepted codes before sending these values.

## Find a country from an ISO code

Use `fromIso2` or `fromIso3` when the input must identify a supported country:

```dart
final fromTwoLetters = Country.fromIso2('br');
final fromThreeLetters = Country.fromIso3(' BRA ');
// Both return Country.brazil.
```

Both methods accept uppercase or lowercase ASCII letters and ignore surrounding
whitespace. Malformed or unsupported codes throw `FormatException`. The
extended identifiers listed above are supported too:

```dart
final ascension = Country.fromIso2('ac'); // Country.ascensionIsland
final kosovo = Country.fromIso3('xkk'); // Country.kosovo
```

Country names, numeric codes, retired codes, and alternate identifiers such
as `UK` or `XKX` are not accepted. Use `GB` for the United Kingdom and `XKK`
for Kosovo's three-letter identifier.

Use `tryFromIso2` or `tryFromIso3` when an unknown value is an expected result:

```dart
final countryOrNull = Country.tryFromIso2('XX'); // null
final anotherCountryOrNull = Country.tryFromIso3('ZZZ'); // null
```

These methods apply the same normalization and return `null` instead of
throwing for malformed or unsupported codes.

## Read a localized display name

Use `displayName` when presenting a country to a person. Pass the locale that
should be shown:

```dart
final name = Country.brazil.displayName(const Locale('pt', 'BR')); // Brasil
```

The lookup is synchronous and works offline. Android, iOS, macOS, and Windows
10 version 1903 or newer use the operating system's translations; web uses
the browser's translations. Linux and older Windows installations include
translations from the package's pinned Unicode CLDR
release. No locale list or translation download needs to be configured.

Language, region, and script can affect the name. For example, `zh-TW` selects
Traditional Chinese while `zh-CN` selects Simplified Chinese. The platform
can choose a nearby locale when an exact match is unavailable. If no matching
translation is available, the result falls back to English. Older embedded
browsers without country-name translation support also return English.

Supported translations and wording can differ between platforms and change
with operating-system, browser, or package updates. Display names are
presentation text; store `iso2` or `iso3` when a stable identifier is required.

## Read a primary calling code

Use `callingCode` to obtain a country calling code for a phone-input default:

```dart
final callingCode = Country.brazil.callingCode; // '55'
final prefix = callingCode == null ? null : '+$callingCode'; // '+55'
```

The result is a nullable string containing digits without `+` or national area
codes. Countries sharing a numbering plan share a code: the United States and
Canada both return `1`.

Saint Helena, Ascension Island, and Tristan da Cunha are individually
accessible:

```dart
final saintHelenaCode = Country.saintHelena.callingCode; // '290'
final ascensionCode = Country.ascensionIsland.callingCode; // '247'
final tristanCode = Country.tristanDaCunha.callingCode; // '290'
```

`Country.saintHelena` keeps the ISO identifiers `SH` and `SHN`, which cover the
combined territory in ISO. Use the individual entries when the distinction
matters, such as choosing Ascension's calling code.

Each entry provides only one primary calling code. It is a default, not a
complete list of ways to reach every location within a territory.

When no reliable primary mapping is available, the result is `null`, as for
`Country.antarctica`. This does not mean phone service is unavailable.

A calling code alone does not uniquely identify a country or validate a phone
number. Concatenating it with domestic input may require more than adding a
prefix, because domestic dialing conventions vary. Use the separate
[`PhoneNumber` utility](phone_number.md) for complete international numbers.

See the
[`Country` API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/Country.html)
for the complete member contracts.
