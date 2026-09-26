# RouteListener

Use `RouteListener` to run an action after the current route finishes moving, or
when navigation starts moving away from it. The listener leaves its child visible
and does not change its layout.

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
