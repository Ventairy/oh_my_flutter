# Group

`Group` connects widgets that belong together even when they live under different
parents. Share a stable `GroupLink` between the members. Each widget keeps its
usual layout and interaction.

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

final content = GroupLink();

Group(link: content, child: body);
Group(link: content, zIndex: 1, child: header);
Group(link: content, zIndex: 2, child: footer);
```

Keep the link in your State instead of creating it during every build. Members
leave the group when removed. The link needs no disposal.

## Measure

After layout, ask for the combined bounds relative to a widget:

```dart
final bounds = content.measure(relativeTo: referenceContext);
```

The reference context must identify an attached render box in the same Flutter
view. The result includes member positions and transforms. An empty or
unavailable group returns `null`.

## Capture

Capture the combined content without moving or rebuilding its widgets:

```dart
final snapshot = await content.capture(
  relativeTo: referenceContext,
  pixelRatio: 2,
);
if (snapshot == null) return;
try {
  final image = await snapshot.toImage();
  try {
    // Display, encode, or share the image.
  } finally {
    image.dispose();
  }
} finally {
  snapshot.dispose();
}
```

The snapshot includes the union of member bounds by default. Pass `bounds` to
choose a specific rectangle in the reference widget's coordinates. The default
pixel ratio is the Flutter view's device pixel ratio. Empty, unavailable, and
oversized captures return `null` rather than a partial image.

`zIndex` controls snapshot stacking: higher values appear above lower ones;
equal values preserve registration order. It does not reorder the original
widgets. A same-link member nested inside another member appears only once,
inside its outer member's capture.

Capture includes child rendering and positioning, but not opacity or clipping
from outside the Group. Put effects inside the member when they belong in the
snapshot. Platform views that cannot be captured make the capture unavailable.

## Paint and dispose

Use `snapshot.paint(canvas, offset)` in a custom painter to draw a snapshot
repeatedly. The offset places the snapshot's top-left corner; `snapshot.bounds`
still identifies its rectangle in the original reference coordinates.

Snapshots remain usable after their members unmount. Dispose each snapshot when
finished. Images returned by `toImage()` have their own lifetime and must also
be disposed.

## Use with Morph

In a custom flight delegate's `properties` method, register the endpoint's group:

```dart
@override
Widget properties(MorphEndpointContext endpoint) {
  return endpoint.groupSnapshot(content);
}
```

Use a separate link for each endpoint appearance. Return the registered widget
from your flight, applying the desired scale or fade to it. Morph captures using
the endpoint's rectangle, temporarily hides the originals during flight, and
restores them at handoff. Nested Morphs retain their own transitions and are
excluded from this enclosing flight snapshot. Ordinary `GroupLink.capture()`
still captures nested Morph widgets as part of the group's rendered content.

See [Morph](morph.md) for custom delegates and navigation setup.
