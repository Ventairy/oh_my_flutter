# RouteListener

Use `RouteListener` to respond to navigation around a screen. The listener
leaves its child visible and does not change its layout.

## Settlement callbacks

```dart
RouteListener(
  onSettled: () => showReadyMessage(),
  onUnsettled: () => dismissReadyMessage(),
  child: const MyPage(),
)
```

Provide at least one callback. `onSettled` runs once after the enclosing route
enters, after a covering route finishes leaving, and after a navigation gesture
is cancelled. `onUnsettled` runs once when that route starts leaving, becomes
covered, or enters a navigation gesture. Without an enclosing route, the child
is treated as settled. Disposing the listener does not call either callback;
dispose resources owned by the surrounding widget in its own lifecycle.

Callbacks run after the current frame, in the order of route-state changes.
Updating the child or callback functions does not replay `onSettled` while the
route remains settled.

For complete API details, see the
[RouteListener API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/RouteListener-class.html).

## Progress callback

Use `onProgressChanged` to start an action partway through entry. For example,
this starts a widget animation once the route reaches 60% of its timeline:

```dart
// Fields and method on the surrounding State class.
final MotionController motionController = MotionController();
bool hasPlayed = false;

void handleProgress(double progress) {
  if (hasPlayed || progress < 0.6) return;
  hasPlayed = true;
  motionController.play();
}

// In build:
RouteListener(
  onProgressChanged: handleProgress,
  child: Motion(
    controller: motionController,
    startup: MotionStartup.skip,
    effect: RotateMotionEffect(degrees: 360),
    child: const Icon(Icons.refresh),
  ),
)
```

The callback receives the primary route animation's current value after
mounting, then changed values after each frame. Multiple changes within one
frame produce only the latest value. Entry progresses from `0` to `1`; exit
and interactive back gestures can decrease the value. Covering routes do not
contribute progress. A route's easing can make its visual position differ from
its animation timeline.

Use `>=` for thresholds because frames can skip over an exact value. Keep a
guard in your own widget when an action should run only once. Without an
enclosing route or primary animation, progress is `1`.

You can supply `onProgressChanged` alone. Replacing the callback does not replay
the current value; enabling it after it was null reports the current value.
Disposal stops delivery, including any pending value.
