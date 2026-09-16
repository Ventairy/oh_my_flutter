# Interactive swipe dismissal

`InteractiveSwipeDismiss` lets a user drag any widget away and ask its owner
to remove it. It translates the live child without scaling, clipping, rounding,
or otherwise changing its appearance.

Import the public library:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';
```

## Dismiss a route

The default interaction follows a downward drag. The first movement beyond
its activation distance must favor the dismissal direction. A sideways or
opposite start cannot turn into a dismissal without lifting and starting a new
gesture; small movement before activation does not lock the direction. Returning `true` from
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

## Follow the child's position

Use `onPositionChanged` to keep other content in sync with the child's movement,
including its return after cancellation or rejected dismissal.

```dart
InteractiveSwipeDismiss(
  onDismiss: () => Navigator.maybePop(context),
  onPositionChanged: (offset, directionalFraction) {
    position.value = offset; // A ValueNotifier<Offset> owned by your widget.
  },
  child: content,
)
```

The offset is the child's translation from its resting position in logical
pixels, after sensitivity and direction constraints. Free drag reports both
axes. Each distinct change is reported synchronously, including every return
animation update and the final `Offset.zero`; updates are not batched by frame.

`directionalFraction` measures how far the child moved toward `direction`,
divided by its height for up/down or width for left/right. For example, `0.5`
means half its size, `1.0` its full size, and `2.0` twice its size. Sideways
movement does not contribute; opposite movement reports zero. The fraction
uses the actual offset after sensitivity, independently of `dismissFraction`,
which uses raw finger travel.

Size and direction are captured at gesture start and retained through the
return, even if the child resizes or configuration changes. An unavailable or
nonpositive size reports a fraction of zero. Position changes still notify
when only the sideways offset changes and the fraction stays the same.

Unchanged positions do not notify, including gestures that only scroll or are
kept stationary by reduced motion. Mounting and disposal do not notify, and an
accepted dismissal keeps its final position without reporting a reset. The
callback is captured when the gesture starts and remains in use through the
return; replacing it takes effect on the next gesture.

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
    dismissFraction: 0.4,
  ),
  onDismiss: () => removeOverlay(),
  child: content,
)
```

With `freeDrag: false`, the child moves only toward `direction`. With
`freeDrag: true`, it follows the pointer on both axes after a directional
dismissal drag begins.

`sensitivity` changes only the visible translation. `dismissFraction` is the
fraction of the wrapped child's height (vertical dismissal) or width
(horizontal dismissal) that the finger itself must travel before release.
For example, `0.5` on a 200 px-tall child requires 100 px of downward travel.
The measured size includes padding inside the wrapper and is captured when
the gesture starts, so resizing does not change an active gesture's distance.
A sufficiently fast swipe toward `direction` can dismiss before that distance
is reached.

See the
[API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/InteractiveSwipeDismiss-class.html)
for every configuration member.

## Customize the return animation

Choose how the child returns after an incomplete drag, pointer cancellation,
or rejected dismissal:

```dart
InteractiveSwipeDismiss(
  dragConfig: const InteractiveSwipeDismissDragConfig(
    returnCurve: Curves.easeOutCubic,
    returnDuration: Duration(milliseconds: 300),
  ),
  onDismiss: () => Navigator.maybePop(context),
  child: content,
)
```

A zero duration restores immediately; reduced motion also skips the return animation. Settings are
captured when a gesture starts, so changes apply to the next gesture.

## Observe movement outside the dismissal direction

Use `onOverdrag` to receive movement that the wrapper does not translate:

```dart
InteractiveSwipeDismiss(
  onOverdrag: (offset) => overdragOffset.value = offset,
  onDismiss: () => Navigator.maybePop(context),
  child: content,
)
```

Here, `overdragOffset` is a consumer-owned `ValueNotifier<Offset>`. The callback
only reports input; it does not move the child.

For a gesture eligible for downward dismissal, downward travel remains normal.
Upward and sideways travel is reported together, including diagonal pulls. Offsets are accumulated
logical pixels before sensitivity, with negative x for left and negative y
for up. The callback runs when this restricted offset changes. Moving back
into the allowed direction, releasing, or cancelling reports zero when needed.

If the initial direction rules out dismissal, the callback reports the entire
accumulated drag offset. Turning toward the dismissal direction stays overdrag
until the finger lifts; returning to the starting position reports zero.

Scrollable content keeps the gesture until its touched scroll chain reaches
the boundary in the pull direction. Handles can begin overdrag regardless of
scroll position. Once the wrapper owns the drag, scrolling stays fixed until
release. Settings are captured at gesture start.

With `freeDrag: true`, movement is unrestricted, so no overdrag is reported.
Reduced motion still reports input; consumers are responsible for respecting
reduced motion in any visual response they add.
