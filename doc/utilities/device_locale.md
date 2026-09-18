# Device locale

Use `DeviceLocale` to work with the device's language and regional preferences.
Create it directly or access it through `Device.locale`. Applications can supply
an alternative implementation for testing.

## Get the configured country

`getCountry()` returns a `Country?` for the configured region. It can help choose
an initial country for a phone-number input while allowing the user to change it.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

Future<Country> initialPhoneCountry({required Country fallback}) async {
  return await const DeviceLocale().getCountry() ?? fallback;
}
```

The country describes regional preferences. It does not establish physical
location, the SIM provider's country, a phone number's country, or an account's
country. Applications choose their own fallback; no country is inferred from a
language or substituted from the SIM, GPS, or network.

### Platform behavior

| Platform      | Country source                                                                                                 |
| ------------- | -------------------------------------------------------------------------------------------------------------- |
| Android       | The first system locale's region, including an explicit regional override. App-language overrides are ignored. |
| iOS and macOS | The regional preference exposed by Foundation.                                                                 |
| Windows       | The user's configured country or region, on Windows 10 version 1709 and newer.                                 |
| Linux and web | Unavailable; returns null.                                                                                     |

Missing settings, unrecognized countries, and failed lookups return null.
Regions spanning multiple countries, such as Latin America (`419`), also return
null. Android does not scan later preferred languages when the first locale
cannot identify a country.

Each call reads again so subsequent calls can reflect changed settings. No
permission prompt, added dependency, or application setup is required. Windows
versions without the required system API return null.

## Substitute locale behavior

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

class ExampleLocale implements DeviceLocale {
  const ExampleLocale();

  @override
  Future<Country?> getCountry() async => Country.brazil;
}

const device = Device(locale: ExampleLocale());
```

See the [API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/DeviceLocale-class.html)
for the public contract.
