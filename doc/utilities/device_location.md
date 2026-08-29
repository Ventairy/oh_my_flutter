# Device location

Use `DeviceLocation` to manage foreground location permission and retrieve
fresh coordinates or a device-formatted current address on Android or iOS.

The supported native targets are Android 7.0 (API 24) or newer and iOS 15 or
newer, matching the minimums of the supported Flutter toolchain.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final coordinates = await const DeviceLocation().getCurrentCoordinates();

print(coordinates.latitude);
print(coordinates.longitude);
print(coordinates.accuracy);
```

By default, `getCurrentCoordinates()` requests foreground permission when it is
missing. The request uses the best accuracy the user and device allow.
`accuracy` is the estimated horizontal uncertainty in meters; a smaller value
is more precise. Android approximate location and iOS reduced accuracy remain
valid results, so do not assume that every result is precise.

Overlapping coordinate calls share one acquisition. After it completes, the
next call asks for fresh coordinates. The operating system controls how long
acquisition takes; the package does not expose a timeout or return a cached
result.

## Retrieve the current address

Call `getCurrentAddress()` when the application needs a readable description
of the user's current location:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final address = await const DeviceLocation().getCurrentAddress();

showCurrentStreet(address.street ?? address.formattedAddress);
```

The returned `DeviceLocationAddress` keeps the coordinates used for the lookup
and exposes `formattedAddress`, `name`, `street`, `streetNumber`,
`neighborhood`, `district`, `city`, `state`, `postalCode`, `country`, and
`countryCode`. Every text field is nullable because the device can return only
the detail available for that location. A regional result might contain a city
and country without a street, for example.

`formattedAddress` uses the device's address formatting and can contain line
breaks. Select an individual component when the interface needs a shorter
label. Empty device values are returned as null. Two-letter ASCII country codes
supplied by the device are returned uppercase.

Pass a locale when the application prefers a particular language or region:

```dart
import 'package:flutter/widgets.dart' show Locale;

final address = await const DeviceLocation().getCurrentAddress(
  locale: const Locale('pt', 'BR'),
);
```

The locale is a best-effort preference. Device geocoders can return another
locale when localized data is unavailable. A null locale uses the device
locale.

Address lookup first acquires fresh coordinates and therefore follows the same
permission and location-service behavior as `getCurrentCoordinates()`.
`requestPermission: false` guarantees that it does not display a permission
prompt. Matching overlapping lookups share their active work, while a call
made after completion starts a fresh coordinate acquisition and address
lookup.

Device geocoding can require a network connection and does not guarantee an
address or a particular level of accuracy. Do not use the result for
safety-critical or regulatory decisions. When coordinates are available but
the device cannot return a usable address, `getCurrentAddress()` throws
`DeviceLocationException` with `operationUnavailable`.

After fresh coordinates are available, address resolution stops waiting after
30 seconds and reports `operationUnavailable`. The package does not
automatically retry. Applications making frequent sequential refreshes should
pace retries and wait for a later user action or connectivity change after a
failure.

## Manage permission explicitly

Check permission without showing a prompt:

```dart
const location = DeviceLocation();
final status = await location.permissionStatus;
```

Request foreground permission independently of location services:

```dart
final status = await location.requestPermission();
if (status.isGranted) {
  final coordinates = await location.getCurrentCoordinates(
    requestPermission: false,
  );
}
```

Passing `requestPermission: false` guarantees that coordinate acquisition does
not display a permission prompt. Instead, missing permission throws a
`DeviceLocationException` with `permissionDenied` or
`permissionPermanentlyDenied`.

`DeviceLocationPermissionStatus` distinguishes `notDetermined`, `denied`,
`deniedForever`, `restricted`, `whileInUse`, and `always`. Its `isGranted`
getter is true for `whileInUse` and `always`. Android permission checks report
ungranted access as `denied`; Android only reports `deniedForever` when a
permission request confirms that another dialog cannot be shown. iOS reports a
system denial as `deniedForever` because the app cannot show the prompt again.

Overlapping permission calls share one native request so the application never
starts two system prompts at once.

## Open application settings

Offer settings as an explicit recovery action after a permanent denial:

```dart
final opened = await location.openLocationSettings();
```

Android and iOS open the application's system settings page. Apple does not
provide a supported link directly to the location row. The returned boolean
reports whether the operating system accepted the navigation request; it does
not report whether the user changed permission.

## Handle unavailable operations

Catch `DeviceLocationException` and use its reason to present localized,
application-owned guidance:

```dart
try {
  final coordinates = await location.getCurrentCoordinates();
  useCoordinates(coordinates.latitude, coordinates.longitude);
} on DeviceLocationException catch (error) {
  switch (error.reason) {
    case DeviceLocationExceptionReason.servicesDisabled:
      showEnableLocationServicesMessage();
    case DeviceLocationExceptionReason.permissionDenied:
      showPermissionRationale();
    case DeviceLocationExceptionReason.permissionPermanentlyDenied:
      showPermissionRecoveryMessage();
    case DeviceLocationExceptionReason.configurationMissing:
      reportLocationConfigurationError();
    case DeviceLocationExceptionReason.unsupportedPlatform:
      hideCurrentLocationAction();
    case DeviceLocationExceptionReason.operationUnavailable:
      showOperationUnavailableMessage();
    case DeviceLocationExceptionReason.coordinatesUnavailable:
      showTryAgainMessage();
  }
}
```

`coordinatesUnavailable` can be retried after an appropriate user action.
`operationUnavailable` covers a platform operation that could not run, such as
settings navigation while the application has no usable native lifecycle or a
current address that the device could not resolve.

## Configure Android

Only applications that use `DeviceLocation` need location permissions. Adding
`oh_my_flutter` by itself does not add them to the application manifest.

Add foreground location permission as a direct child of the `<manifest>`
element in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

`ACCESS_COARSE_LOCATION` is required. Add `ACCESS_FINE_LOCATION`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

when the feature benefits from precise coordinates, such as pre-filling a street
address. When both are declared, `DeviceLocation` requests them together as
Android requires; the user can still choose approximate access.

If location hardware should not restrict the application's Play Store device
availability, declare the capabilities as optional:

```xml
<uses-feature android:name="android.hardware.location" android:required="false" />
<uses-feature android:name="android.hardware.location.gps" android:required="false" />
<uses-feature android:name="android.hardware.location.network" android:required="false" />
```

Do not add background-location or location foreground-service permissions for
`DeviceLocation`; it performs only one-shot foreground requests.

## Configure iOS

Only applications that use `DeviceLocation` need a location purpose string.
Adding `oh_my_flutter` by itself does not include Core Location access in the
release application.

Add a user-facing reason to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Use your location to choose the current address.</string>
```

Write a purpose string specific to the application's feature and localize it
with the application's `InfoPlist.strings` files when the application supports
multiple languages. No background-location key or package-specific CocoaPods,
Swift Package Manager, or build configuration is required. iOS support requires
Flutter's Swift Package Manager integration, which is enabled by default by the
supported Flutter version. Projects that explicitly disable it are not
supported.

iOS users can grant reduced accuracy. `DeviceLocation` respects that choice and
does not request temporary full-accuracy access.

## Privacy and store disclosures

`DeviceLocation` returns coordinates and address data to the calling
application in memory.

## Other platforms

Web, macOS, Windows, and Linux are not supported in the current version. Any
operation on those platforms throws `DeviceLocationException` with
`DeviceLocationExceptionReason.unsupportedPlatform`.

See the [generated API reference](../api/oh_my_flutter/DeviceLocation-class.html)
for the complete member contracts.
