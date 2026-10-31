# Device accelerometer

Use `DeviceAccelerometer` to respond to movement measured by an Android or iOS
device. For example, an application can react when its user tilts or shakes
their phone.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

const accelerometer = DeviceAccelerometer();
// The same capability is available as const Device().accelerometer.
```

## Check availability

```dart
final available = await accelerometer.isAvailable;
```

This check does not start sampling or request permission. It returns false on
unsupported platforms and devices without an accelerometer, including typical
iOS simulators. Unexpected access failures throw `DeviceAccelerometerException`.
Availability does not guarantee that a later subscription will succeed.

## Watch acceleration

```dart
final subscription = accelerometer.watch().listen(
  (sample) {
    print('${sample.x}, ${sample.y}, ${sample.z} m/s²');
  },
  onError: (Object error) {
    if (error is DeviceAccelerometerException) {
      print(error.reason);
    }
  },
);

// When the screen or owner no longer needs readings:
await subscription.cancel();
```

Readings include gravity. Their combined magnitude is normally about 9.81 m/s²
when the device is stationary. They are acceleration, not position, velocity,
rotation angles, or gravity separated from movement.

Axes remain fixed to the device's reference orientation, usually portrait on a
phone, even if the application's display rotates:

- `x`: left to right.
- `y`: bottom to top.
- `z`: perpendicular to the screen, positive outward.

A stationary phone lying face up normally has positive `z` around 9.81 m/s².
Both supported platforms use the same units and signs. Sensor noise and physical
hardware differences remain observable.

### Sampling interval

The default requests one reading every **200 milliseconds**, approximately five
per second. For a faster effect, request a shorter interval:

```dart
final readings = accelerometer.watch(
  samplingInterval: const Duration(milliseconds: 20),
);
```

The interval must be positive. It is a request rather than an exact clock:
hardware and operating-system limits can produce different timing. Slower
subscriptions do not receive additional readings merely because another
subscriber requested a faster interval. No readings are invented to fill gaps.

On Android 12 and newer, requests above 200 Hz can require the host application's
`android.permission.HIGH_SAMPLING_RATE_SENSORS` manifest permission. Platform
limits can still apply after declaring it. Ordinary accelerometer observation
does not display a permission prompt on Android or iOS; this API does not request
motion-history or fitness access.

### Measurement time

`sample.timestamp` is the monotonic device measurement time, exposed as a
`Duration` with microsecond resolution. Subtract two timestamps to find elapsed
time between readings. Do not convert it to a calendar date or compare values
across devices or device boots. Delivery can happen after measurement, so use
sample timestamps rather than callback arrival time for timing-sensitive work.

### Subscription ownership

Creating the utility or calling `watch()` alone does not activate sampling.
The returned broadcast stream supports multiple listeners without replaying
previous readings. Cancel subscriptions when their owner no longer needs them;
await cancellation when subsequent work depends on cleanup being complete.

Observation suspends whenever the app is not resumed. Existing subscriptions
continue with fresh readings on return, without replaying background history.
Expect a timestamp gap and reset application-owned elapsed-time accumulation
when appropriate. Cancel observations for hidden routes yourself.

`subscription.pause()` follows normal Dart buffering behavior. For live effects,
cancel and subscribe again when readings become useful rather than pausing for
an extended period. Create and retain the stream outside widget `build` methods
when using `StreamBuilder`.

## Handle failures

`DeviceAccelerometerException.reason` distinguishes:

- `unsupportedPlatform`: this package has no implementation for the platform.
- `sensorUnavailable`: no accelerometer is available on this device.
- `permissionDenied`: system permissions or policy prevent access.
- `operationUnavailable`: another native access or delivery failure occurred.

A watch failure emits an error and closes affected subscriptions. Subscribe
again to retry; there is no automatic retry. The optional exception `cause`
provides diagnostic context. Supply an implementation of `DeviceAccelerometer`
to your own consumers or `Device(accelerometer: ...)` for deterministic tests.

The [API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/DeviceAccelerometer-class.html)
provides the complete member contracts.
