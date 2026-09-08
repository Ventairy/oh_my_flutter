# MaybeSafeArea

Use `MaybeSafeArea` for a floating, positioned, transformed, or scrolling
widget that should avoid a device's unsafe edges only when it reaches them.

## Basic usage

```dart
const Stack(
  children: [
    Positioned(
      top: 0,
      right: 24,
      child: MaybeSafeArea(
        child: CloseButton(),
      ),
    ),
  ],
)
```

A child in the middle of the view stays in its original position. When its
bounds overlap an enabled unsafe edge from `MediaQuery.padding`, the child
moves only far enough to clear that edge. The adjusted position is used on the
first rendered frame, without an animation or delayed child mount, and remains
current while the child scrolls or transforms. Horizontal and vertical
avoidance are resolved independently.

## Choosing how avoidance follows movement

The default `MaybeSafeAreaBehavior.live` keeps checking the child's painted
position. Use it for an independently moving control that must become safe as
it scrolls or animates toward a view edge.

Use `MaybeSafeAreaBehavior.preserve` when a larger surface moves as a unit and
the child must keep its position within that surface:

```dart
const MaybeSafeArea(
  behavior: MaybeSafeAreaBehavior.preserve,
  left: false,
  right: false,
  bottom: false,
  child: ViewHeader(),
)
```

Preserved avoidance is resolved at the child's first rendered position. That
correction then travels with the child and its ancestors instead of changing
as the surface moves. It is resolved again when the unsafe padding, viewport,
pixel ratio, enabled edges, behavior, or child's layout size changes.

The nearest `MediaQuery.padding` defines which areas are unsafe. An ancestor
`SafeArea` may remove padding that it has already handled, so a nested
`MaybeSafeArea` does not avoid that edge again. Place `MaybeSafeArea` outside
that `SafeArea` when it must react to the same edge. `MaybeSafeArea` leaves the
padding unchanged for its own descendants.

All four physical edges are enabled by default. Disable an edge that the child
is allowed to overlap:

```dart
const MaybeSafeArea(
  left: false,
  right: false,
  bottom: false,
  child: PlaybackControls(),
)
```

## Morph transitions

For a compact `Morph` child, place a live `MaybeSafeArea` outside the `Morph`
so both endpoints are measured at their avoided positions, including when a
route has not painted its destination yet:

```dart
const MaybeSafeArea(
  left: false,
  right: false,
  bottom: false,
  child: Morph(
    tag: 'view-header',
    child: ViewHeader(),
  ),
)
```

Keep `MaybeSafeArea` outside a `MorphDescendant` whose flight behavior is
`MorphDescendantFlightBehavior.snapshot`. A snapshot cannot change its
safe-area response after capture while it moves through the view.

## Layout behavior

`MaybeSafeArea` changes the child's visible and interactive position without
changing its layout size, constraints, surrounding layout, scroll extent, or
descendant `MediaQuery`. This makes it suitable for compact overlays and
controls whose surrounding layout must remain stable.

Place it where ancestor paint and hit-test bounds include the adjusted
position, such as directly inside a full-screen `Stack` or `Overlay`. A tight
or clipping ancestor can cut off the moved paint or reject input before it
reaches `MaybeSafeArea`.

Avoidance is based on the widget's layout bounds after ordinary two-dimensional
ancestor translations, scales, or rotations. Paint outside those bounds, such
as a shadow or a transform inside the child, is not included. Put
`MaybeSafeArea` inside a transform that should affect detection. Perspective
transforms are not supported.

If the child cannot fit within the portion of the view left by enabled unsafe
edges, it moves only as much as needed to cover that safe span and clips the
excess. A child that already covers the safe span, such as full-screen content,
does not move. Use Flutter's `SafeArea` when content must reflow, siblings must
reserve the avoided space, or a large child must receive smaller constraints.

## Observing adjusted bounds

Use `MaybeSafeAreaHandle` to coordinate another widget with content protected by
`MaybeSafeArea`. It lets a renderer read the corrected bounds and lets listeners
respond when those bounds change, including when an ancestor moves.

### Connect and observe

Create the handle in the owning widget's state and attach it to one
`MaybeSafeArea`. Register listeners once and remove them when no longer needed.
The owner disposes the handle. Import the API from
`package:oh_my_flutter/oh_my_flutter.dart`.

```dart
final handle = MaybeSafeAreaHandle();

// In the owning widget's build method:
MaybeSafeArea(
  handle: handle,
  bottom: false,
  child: header,
)
```

A listener may read `handle.adjustedBounds` and request a refresh. Notifications
arrive after the frame, combine changes within a frame, and stop repeating when
bounds stay unchanged. Removing the attached widget reports unavailable bounds.

```dart
void handleBoundsChanged() {
  final bounds = handle.adjustedBounds;
  // Respond to the latest bounds, or null after disconnection.
}

// Register during setup:
handle.addListener(handleBoundsChanged);

// During cleanup:
handle.removeListener(handleBoundsChanged);
handle.dispose();
```

### Read bounds at the right time

`adjustedBounds` returns a nullable `Rect` in the attached `MaybeSafeArea` box's
local logical coordinates. For example, a 100 by 40 child moved down 24 logical
pixels has bounds `Rect.fromLTWH(0, 24, 100, 40)`. These are not global screen
coordinates. A transformed child may have an enclosing rectangle rather than
an axis-aligned translation of its original bounds.

Read bounds during painting, hit testing, semantics, or in the listener. Do not
use the getter during build or layout: ancestor positions may not be finalized.
Before attachment or usable layout, the result is null. A rendering-time read
can resolve the current correction even before the protected child paints.

A notification can update another widget on the next frame; it cannot reflow
content already drawn in the current frame. Rapid movement may therefore leave
listener-driven content one frame behind. Captured images do not reflow, and
capturing protected content does not publish capture-specific bounds to live
listeners.

The handle follows the attached widget's [avoidance behavior](#choosing-how-avoidance-follows-movement).
It does not control that behavior or add spacing for other widgets.
