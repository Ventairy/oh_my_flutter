# Device

Use `Device` to keep the package's device features together when an application
needs more than one of them.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

const device = Device();

final coordinates = await device.location.getCurrentCoordinates();
final cornerRadii = await device.display.cornerRadii(context);
final simCountry = await device.sim.getCountry();
final configuredCountry = await device.locale.getCountry();
```

Each property exposes the same independently usable feature class that can be
created directly. Use `Device` when one owner, service, or widget needs a
single object for several device capabilities; use `DeviceLocation` or
`DeviceDisplay`, `DeviceSim`, or `DeviceLocale` directly when only that capability is needed.

The default constructor creates the standard feature objects. A caller can
also supply its own instances when it needs configured implementations or test
doubles:

```dart
final device = Device(
  location: applicationLocation,
  display: applicationDisplay,
  sim: applicationSim,
  locale: applicationLocale,
);
```

`Device` does not request permission or start an operation when it is created.
Permissions, unsupported-platform behavior, and returned values remain the
contract of the feature property being used.

See the [device location](device_location.md),
[device display](device_display.md), [device SIM](device_sim.md), and
[device locale](device_locale.md) guides for each feature's behavior and
constraints. The [generated API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/Device-class.html)
lists the complete constructor and member contracts.
