# Device display

Use `DeviceDisplay` to read information about and interact with the device
display. It is the package's entry point for display-related capabilities,
whether used directly or through a shared `Device` object.

## Corner radii

`cornerRadii()` returns the radii in logical pixels as a Flutter
`BorderRadius`, so each corner can be used directly by decoration, clipping,
and shape APIs.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final radii = await const DeviceDisplay().cornerRadii(context);

if (radii != null) {
  showEdgeSurface(borderRadius: radii);
}
```

The same feature is available through a shared `Device` object:

```dart
const device = Device();
final radii = await device.display.cornerRadii(context);
```

By default, `cornerRadii()` returns only exact corner data exposed to Flutter
for the current view. It returns null when Flutter does not provide that data.
An exact zero radius is a valid result and is never treated as missing.

### Allow an estimate

Set `estimate: true` when an approximate result is preferable to no result:

```dart
final radii = await const DeviceDisplay().cornerRadii(
  context,
  estimate: true,
);
```

Exact Flutter data always wins, even when estimation is allowed. When exact
data is unavailable, Android may consult display information supplied by the
operating system or device manufacturer before using the approximate phone
fallback. The package does not install a native display-corner probe on iOS;
on iOS, a missing Flutter value can only use the approximate phone fallback.

An estimate is intended for visual alignment, such as making a surface near a
screen edge feel concentric with the display. It is not a physical
measurement, and future or unusual devices can differ from the returned
value. Do not use it for safety-critical placement, hardware identification,
or avoiding camera housings and other display cutouts. Continue to use
Flutter's safe-area and display-feature APIs for content avoidance.

The approximate fallback is limited to phones. Tablets, desktop platforms,
web, and other form factors return null unless Flutter or a supported platform
signal provides usable corner data. A fallback-enabled call also returns null
when the current view does not provide enough valid display geometry to form a
responsible estimate.

Call the method again after moving the view to another display or when the
application needs a value for a new layout configuration. The returned
logical-pixel values belong to the view represented by `context` at the time
of the call.

See the
[generated API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/DeviceDisplay-class.html) for
the complete member contract.
