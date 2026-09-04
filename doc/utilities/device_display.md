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

`cornerRadii()` first returns corner data exposed by Flutter for the current
view. When Flutter does not provide it, the package asks supported mobile
platforms for trustworthy display information:

- Android 12 (API 31) and newer can provide the current rounded corners
  directly.
- Older Android versions can use corner sizes declared by the device
  manufacturer when the app occupies an unambiguous default display.
- iOS 26 and newer can provide the display shape through public UIKit APIs.
- iOS 15 through 25 return null when Flutter has no value because those
  versions do not expose a public display-corner measurement.
- Web, desktop platforms, and unsupported display configurations return null
  when Flutter has no value.

A zero radius is a valid result and is never treated as missing. The package
does not infer a radius from the safe area, device dimensions, model name, or
another approximate signal. Continue to use Flutter's safe-area and
display-feature APIs for avoiding system interfaces and display cutouts.

Call the method again after moving the view to another display or when the
application needs a value for a new layout configuration. The returned
logical-pixel values belong to the view represented by `context` at the time
of the call.

See the
[generated API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/DeviceDisplay-class.html) for
the complete member contract.
