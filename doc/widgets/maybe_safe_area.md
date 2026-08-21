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

For a compact `Morph` child, place `MaybeSafeArea` outside the `Morph` so both
endpoints are measured at their avoided positions, including when a route has
not painted its destination yet:

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
