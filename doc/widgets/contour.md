# Contour

`Contour` draws a colored border around the visible edges of a widget. It can
give text a contrasting outline or make an icon appear raised with a border and
shadow. The original content stays visible and interactive.

## Add a contour

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Padding(
  padding: const EdgeInsets.all(24),
  child: Contour(
    color: Colors.white,
    amount: 6,
    shadows: const [
      Shadow(
        color: Color(0x33000000),
        offset: Offset(0, 4),
        blurRadius: 8,
      ),
    ],
    child: const Text(
      'Armando?',
      style: TextStyle(fontSize: 48, color: Colors.blue),
    ),
  ),
)
```

The contour follows the letters rather than the text's rectangular layout.
It expands from every visible edge, including the inner edges of O and A.
Enclosed transparent centers become smaller as expansion increases and close
naturally when the expanded edges meet. The same behavior applies to the opening
in C and gaps between neighboring letters. There is no separate interior-fill
operation.

`color` is required. By default there is no expansion and no shadow. Set
`amount` to a nonnegative number of logical pixels to grow the backing without
resizing the child. Expansion uses rounded joins: curves stay smooth and
expanded corners are rounded off without pointed protrusions.

Pass Flutter `Shadow` values to choose colors, offsets, and blur radii. Multiple
shadows appear in list order and follow the expanded backing. Backing opacity
comes from `color`, independently of the child's opacity.

## Wrap icons and other widgets

```dart
Contour(
  color: Colors.yellow,
  amount: 3,
  child: const Icon(Icons.favorite, size: 40, color: Colors.red),
)
```

The effect works with Flutter-painted widgets and compositions, including text
and icon wrappers supplied by a design system. Any opaque child background is
part of the resulting shape. Images naturally follow their visible pixels;
images with an opaque rectangular background produce a rectangular backing.
Completely transparent content produces no backing.

## Ignore faint specks

Nearly transparent paint and tiny faint fragments do not produce an enlarged
contour. This prevents barely noticeable pixels in artwork, such as
emoji, from turning into prominent dots or uneven borders. The child itself is
never changed. Visible translucent artwork and small opaque details, including
punctuation, still receive a contour.

## Leave room around the content

The widget preserves its child's layout size, text baseline, interaction, and
accessibility information. Expansion and shadows can paint outside that space.
Use surrounding `Padding` when they need room; ancestor clipping can cut them
off. The backing itself does not create an additional tap target.

## Prepare before an entrance

Set `prepareWhenHidden: true` to prepare a mounted, laid-out `Contour` while an
ancestor keeps it hidden, such as `Opacity(opacity: 0)` or `Offstage`. This lets a planned
entrance begin with its backing ready instead of spending part of the animation
waiting for it. Hidden preparation does not reveal the content.

Attach a `ContourController` and listen for `isReady` to start an entrance when
preparation finishes. For example, hold `Motion` at its initial state and play
it once the artwork is ready:

```dart
class PreparedArtwork extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<PreparedArtwork> createState() => _PreparedArtworkState();
}

class _PreparedArtworkState extends State<PreparedArtwork> {
  final _contour = ContourController();
  final _motion = MotionController();
  var _played = false;

  @override
  void initState() {
    super.initState();
    _contour.addListener(_startEntrance);
  }

  void _startEntrance() {
    if (_played || !_contour.isReady) return;
    _played = true;
    _motion.play();
  }

  @override
  void dispose() {
    _contour.removeListener(_startEntrance);
    _contour.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Motion(
    controller: _motion,
    startup: MotionStartup.hold,
    effect: const PopMotionEffect(),
    child: Contour(
      controller: _contour,
      prepareWhenHidden: true,
      color: Colors.white,
      amount: 4,
      child: widget.child,
    ),
  );
}
```

Use `PreparedArtwork(child: Text('Hello'))`, for example. The animation applies
to the complete contour and child, and retains `Motion`'s reduced-motion
behavior. The example plays once; changing the artwork later does not restart
its entrance. Each controller can attach to only one `Contour` at a time.

For an entrance shared by several contours, give each one its own controller.
Listen to them together with Flutter's `Listenable.merge(controllers)` and start
the shared animation when `controllers.every((controller) => controller.isReady)`
is true. The contours prepare automatically; the application chooses when the
entrance begins.

`isReady` means the current content can be revealed. It also becomes true when
no decoration is visible or when preparation finishes without a backing for
unsupported content, so an entrance is not left waiting forever. It does not
mean the content has already appeared on screen. Notifications arrive after the
current synchronous work finishes, and repeated readiness changes can be
combined into the latest value.

Readiness describes the artwork currently painted by the child. If the child
shows a placeholder while loading assets or data, also wait for its loading
state before starting the entrance. `isReady` does not await future content.

Keep the same `Contour` mounted with the layout constraints it will use when
shown. Removing it or changing its size can require new preparation. Prepare
the actual mounted widget you intend to show. Keep the artwork stable during
hidden preparation; this is most useful for content you expect to reveal
soon.

### Refresh artwork that changes while hidden

After changing a painter or other artwork imperatively while it is hidden,
request preparation again:

```dart
// Update the hidden artwork, then request its current contour.
contourController.prepare();
```

This is useful when the artwork is inside a separate `RepaintBoundary` and its
paint changes do not rebuild the `Contour`. Wait for `isReady` again before
revealing the updated artwork. `prepare()` can request hidden preparation even
when `prepareWhenHidden` is false; it does not reveal the child. Calling it
without an attached `Contour`, or after disposing the controller, does nothing. Request it
after a relevant content change rather than on every animation frame.

## Changing content and supported rendering

On first display, the child and its contour appear together as soon as the
backing is ready. Layout space is reserved during preparation, and interaction
and accessibility become available when the content appears. Some artwork needs
asynchronous preparation; supported simple boxes can appear in the first frame.
Continuously repainting the child can delay that first appearance. Animate the
complete `Contour` when possible so its artwork can finish preparing.

After the content has appeared, changes to its appearance update the backing
automatically. The live child remains visible while its replacement backing is
prepared; an outdated backing is hidden. Continuously changing artwork may
spend time without a backing. Moving or rotating the entire widget does not
require changing its shape.

Both Skia and Impeller are supported. Platform views, such as embedded native
maps or web views, and other content that cannot be captured as an image are
outside guaranteed support. The live child still appears when its backing cannot
be generated.

Use a standard Flutter build; no custom engine or child configuration is
required. `Contour` selects supported optimizations automatically. Measure the
composition on the devices and renderer used by your application.

The shape is an approximation of the child's visible pixels. Very large widgets
can lose fine detail. Extremely detailed artwork may appear without a backing;
simplify the artwork or contour smaller pieces separately. Prefer smaller,
infrequently changing content on low-end devices; measure your own composition
before using many large or continuously changing backings.

See the API references for
[Contour](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/Contour-class.html)
and [ContourController](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/ContourController-class.html)
for member details.
