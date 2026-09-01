# Interactive swipe dismissal

`InteractiveSwipeDismiss` lets a user drag any widget away and ask its owner
to remove it. It translates the live child without scaling, clipping, rounding,
or otherwise changing its appearance.

Import the public library:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';
```

## Dismiss a route

The default interaction follows a downward drag. Returning `true` from
`onDismiss` accepts the dismissal. Returning `false` restores the child.

```dart
InteractiveSwipeDismiss(
  onDismiss: () => Navigator.maybePop(context),
  child: const Scaffold(
    body: Center(child: Text('Drag down to close')),
  ),
)
```

The callback can complete asynchronously. While it is pending, another
dismissal cannot start. After it returns `true`, remove the wrapper from your
widget tree; the translated child remains in place until removal.

Descendant scrollables retain their normal gesture until the matching edge is
reached. Once dismissal begins, every matching scroll position beneath the
pointer stays at its current offset until the interaction ends.

## Make a region the handle

Wrap a header, toolbar, or any other widget with
`InteractiveSwipeDismissHandle`. Dragging anywhere within the wrapped widget
can begin dismissal even when a descendant scrollable is away from the edge.
The handle does not add styling, padding, or other layout of its own.

```dart
InteractiveSwipeDismiss(
  onDismiss: () => Navigator.maybePop(context),
  child: const Column(
    children: [
      InteractiveSwipeDismissHandle(
        child: SizedBox(
          height: 56,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
              child: SizedBox(width: 48, height: 6),
            ),
          ),
        ),
      ),
      Expanded(child: CustomScrollView(slivers: [])),
    ],
  ),
)
```

Taps and cross-axis gestures within the wrapped widget remain available. Once
movement clearly favors the dismissal direction, the handle owns that gesture
and keeps descendant scrolling fixed while the child is dragged. Use
`hitTestBehavior` only when the region needs different Flutter hit-testing
behavior.

## Configure the drag

Keep direction on the wrapper and drag-only choices in `dragConfig`:

```dart
InteractiveSwipeDismiss(
  direction: InteractiveSwipeDismissDirection.right,
  dragConfig: const InteractiveSwipeDismissDragConfig(
    freeDrag: true,
    sensitivity: 0.8,
    dismissThreshold: 0.4,
  ),
  onDismiss: () => removeOverlay(),
  child: content,
)
```

With `freeDrag: false`, the child moves only toward `direction`. With
`freeDrag: true`, it follows the pointer on both axes after a directional
dismissal drag begins.

`sensitivity` changes only the visible translation. `dismissThreshold` is the
fraction of the matching viewport axis that the finger itself must travel
before release. A sufficiently fast swipe toward `direction` can dismiss
before that distance is reached.

See the
[API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/InteractiveSwipeDismiss-class.html)
for every configuration member.
