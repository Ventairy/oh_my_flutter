# Device SIM

Use `DeviceSim` to access the device's SIM capabilities. Create it directly or
access it through `Device.sim`; applications can substitute an implementation
for testing.

## Get the SIM country

`getCountry()` returns a `Country?` identifying the SIM provider's country. For
example, an application can use it to choose the initial region in a phone-number
input, while allowing the user to select a different country.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

Future<Country> initialPhoneCountry({required Country fallback}) async {
  return await const DeviceSim().getCountry() ?? fallback;
}
```

The application chooses the fallback. `DeviceSim` never substitutes the device
language, locale, network location, or GPS location. A SIM provider's country
is not necessarily where the user is currently located, nor does it prove the
country of the phone number they want to enter. For a calling-code prefix, read
`Country.callingCode` from the selected country; that property can also be null.

### Availability

- **Android:** reads the system-default subscription's SIM provider country.
  With multiple SIMs, this may differ from the subscription selected for mobile
  data. Physical SIMs and eSIMs use the same system selection.
- **iOS, web, and desktop:** return null. Apple's deprecated carrier API does
  not provide reliable SIM-country information for current SDK builds.

No permission prompt or manifest permission is required. Missing SIM data,
unrecognized country identifiers, and failed lookups return null. Each call
reads again, so subsequent calls can reflect changes to the default SIM.

## Substitute SIM behavior

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

class ExampleSim implements DeviceSim {
  const ExampleSim();

  @override
  Future<Country?> getCountry() async => Country.brazil;
}

const device = Device(sim: ExampleSim());
```

See the [API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/DeviceSim-class.html)
for the full public contract, the
[Android SIM-country API](https://developer.android.com/reference/android/telephony/TelephonyManager#getSimCountryIso())
for native availability, and
[Apple's carrier API discussion](https://developer.apple.com/forums/thread/714876)
for the iOS limitation.
