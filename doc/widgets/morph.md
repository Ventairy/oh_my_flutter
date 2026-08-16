# Morph

`Morph` animates a shared visual between two locations or between two versions
of one widget. Matching endpoints use the same tag and must resolve to the same
Flutter `Overlay`.

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
```

## Animate between two locations

Place a `Morph` at each possible location and give both endpoints the same tag.
Show only the endpoint that currently owns the visual. Rebuilding from one to
the other starts the flight.

```dart
Stack(
  children: [
    if (expanded)
      const Align(
        alignment: Alignment.bottomRight,
        child: Morph(
          tag: 'job-title',
          child: Text(
            'A complete job description',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ),
      )
    else
      const Align(
        alignment: Alignment.topLeft,
        child: Morph(
          tag: 'job-title',
          child: Text('Job summary'),
        ),
      ),
  ],
)
```

For example, `setState(() => expanded = !expanded)` transfers the tag to the
newly built endpoint. The endpoint being left is the **departing endpoint**;
the endpoint being shown is the **arriving endpoint**.

Use a distinct tag for every logical shared element. A normal `MaterialApp`
with one `Navigator` already provides an overlay. Endpoints in different nested
navigators or other different overlays cannot match.

## Animate a changed child in place

Changing the child of one mounted `Morph` can also start a flight without
moving to another location. Use a different child key to explicitly represent
a new visual:

```dart
Morph(
  tag: 'status-label',
  child: Text(
    expanded ? 'Ready to publish' : 'Draft',
    key: ValueKey(expanded),
  ),
)
```

An unkeyed child also starts a flight when a rebuild supplies a different
widget instance, which ordinary declarative rebuilds commonly do. Use an
explicit changing key when that in-place animation is intentional. Give
successive children the same non-null key when the rebuild should update the
resting widget without animating; that stable key suppresses the in-place
flight even when the child's configuration or widget type changes.

## Choose the automatic behavior

When `flightDelegate` is omitted, Morph chooses the transition from the two
children:

- Eligible `Text`, `Container`, `DecoratedBox`, and vertical `Column` pairs
  animate their supported visual values.
- Every other pair still moves and resizes between its endpoint rectangles,
  then replaces discrete content at `switchThreshold`.
- If a supported widget arrangement is not eligible for specialization, Morph
  uses the generic behavior automatically. No eligibility check is required in
  application code.

Specialization is best-effort: supported values interpolate smoothly, while
unsupported or discrete values can switch. Use a custom delegate when a
particular property must follow an application-defined interpolation contract.

The default `switchThreshold` is `0.5` and its valid range is 0 to 1. The
departing endpoint supplies it. It controls discrete automatic content changes;
a custom flight delegate defines its own interpolation instead.

## Configure timing and ownership

| Setting            | Default and ownership                                                                                                                                                                         |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `duration`         | 300 ms for a root same-screen flight. An omitted value inherits the nearest Morph ancestor. The departing endpoint wins when endpoints differ. Route flights use the route animation instead. |
| `curve`            | `Curves.linear` for a root flight. An omitted value inherits the nearest Morph ancestor. The departing endpoint wins when endpoints differ.                                                   |
| `switchThreshold`  | `0.5`. The departing endpoint supplies it for automatic content changes.                                                                                                                      |
| `switchTransition` | Omitted by default. The departing endpoint supplies it.                                                                                                                                       |
| `watchDestination` | `false`. Set it on the departing endpoint when the endpoint it travels toward can move or resize.                                                                                             |
| `flightDelegate`   | Omitted by default. Both endpoints must use compatible delegates; the departing endpoint's delegate controls the flight.                                                                      |

If a flight must behave the same in both directions, configure the
direction-dependent values on both endpoints. A route push uses the source as
the departing endpoint; a pop uses the endpoint in the closing route as the
departing endpoint.

Each endpoint first resolves an omitted duration or curve from its own nearest
Morph ancestor. If the resolved endpoint values differ, the departing
endpoint's effective value controls that direction.

Curves that overshoot can produce progress outside the 0 to 1 interval. Custom
delegates should either support that extrapolation or clamp progress when their
visual values require it.

## Configure a descendant relative to its Morph

`MorphDescendant` configures how one descendant subtree participates in its
nearest ancestor `Morph`. Use it when that subtree needs to relate to the Morph
differently from the surrounding descendants. Its current `flightBehavior`
property controls how the subtree is represented during an automatic flight.

Ordinary descendants stay live and lay out against the changing flight size.
Choose a different flight behavior when needed:

| Behavior   | In-flight result                                            | Choose it when                                                                                               |
| ---------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `live`     | A live subtree responds to the current flight constraints.  | Content should reflow or otherwise adapt as the Morph changes size.                                          |
| `snapshot` | A non-interactive image keeps the selected endpoint's size. | Editable, scrollable, keyed, or other uniquely owned state must remain mounted only at the resting endpoint. |
| `hide`     | The selected endpoint's space remains empty.                | The subtree should disappear during the flight without changing the surrounding endpoint layout.             |

For example, snapshot an editor so navigation does not attach its controller,
focus, selection, or scroll position to another live subtree:

```dart
Morph(
  tag: 'editor-surface',
  child: Container(
    decoration: const BoxDecoration(color: Colors.white),
    child: MorphDescendant(
      flightBehavior: MorphDescendantFlightBehavior.snapshot,
      child: SingleChildScrollView(
        controller: descriptionScrollController,
        child: TextField(controller: descriptionController),
      ),
    ),
  ),
)
```

The source snapshot remains visible until `switchThreshold`; the destination
snapshot is visible afterward. The endpoint behavior is selected at the same
time, so matching endpoints may deliberately use different behaviors.

A snapshot is visual only: it does not accept input or animate its own internal
state during the flight. Content that Flutter cannot capture as an image, such
as a platform view, is empty during the flight. Use `hide` when an empty result
is required consistently across platforms.

Use `live` explicitly when a shared wrapper selects behavior dynamically:

```dart
MorphDescendant(
  flightBehavior: MorphDescendantFlightBehavior.live,
  child: Text(expanded ? longDescription : shortDescription),
)
```

Use `hide` to reserve endpoint space without showing content:

```dart
MorphDescendant(
  flightBehavior: MorphDescendantFlightBehavior.hide,
  child: const Text('Visible before and after the flight'),
)
```

`MorphDescendant` works at any depth beneath its nearest Morph and does not
change resting layout, paint, semantics, or state.

The outermost non-live boundary controls its complete subtree, including any
non-live boundaries nested inside it. Use separate sibling boundaries for
independent content. Prefer one boundary around a complete subtree when all of
its content uses the same behavior. A nested Morph remains an independent
shared element.

A custom `MorphFlightDelegate` owns the complete in-flight visual. A
`MorphDescendant` affects that custom flight only if the delegate builds the
wrapped subtree as part of its result.

## Animate a discrete content switch

Use `switchTransition` when discrete automatic content changes should animate
around `switchThreshold`. This includes changed `Text` values, generic widget
pairs, and ordinary content inside specialized Container or Column flights.
Nested `Morph` widgets continue their independent flights.

```dart
Morph(
  tag: 'status-label',
  switchTransition: (child, animation) {
    return FadeTransition(opacity: animation, child: child);
  },
  child: Text(expanded ? 'Ready to publish' : 'Draft'),
)
```

For departing content, the supplied animation moves from 1 to 0. For arriving
content, it moves from 0 to 1. Without a builder, content switches immediately
at `switchThreshold`. Configure the builder on both endpoints when the same
treatment should apply during both forward and reverse flights.

## Follow a moving destination

Set `watchDestination: true` on the morph that departs from when
the endpoint it travels toward can move or resize, for example while keyboard
insets change:

```dart
Morph(
  tag: 'continue-action',
  watchDestination: true,
  child: const ContinueButton(),
)
```

The flight follows its destination until it finishes. The setting has no effect
on flights arriving at the configured Morph. If either direction's destination
can move, enable `watchDestination` on both matching Morphs. Leave it disabled
when destinations remain stationary.

## Coordinate nested Morphs

Nested Morph widgets inherit the nearest Morph ancestor's effective duration
and curve when they omit those settings.

```dart
Morph(
  tag: 'card',
  duration: const Duration(milliseconds: 500),
  curve: Curves.easeOutCubic,
  child: Column(
    children: const [
      Morph(tag: 'card-title', child: Text('Title')),
      Morph(tag: 'card-action', child: Icon(Icons.arrow_forward)),
    ],
  ),
)
```

The nested flights inherit 500 milliseconds and `Curves.easeOutCubic`. Supply
either setting on a nested Morph only when that flight should intentionally use
different timing.

## Animate across routes

Put one endpoint in the current route and the matching endpoint in the route
being opened. Both routes must use the same navigator overlay.

```dart
// Source in the current route.
const Morph(
  tag: 'route-title',
  child: Text('Job summary'),
)

// Open a route containing the destination.
Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (context) {
      return const Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: Morph(
            tag: 'route-title',
            child: Text('Full job description'),
          ),
        ),
      );
    },
  ),
);
```

No particular `PageRoute` type, transparent background, or
`transitionsBuilder` is required. The page transition and Morph can run
together. Use a transparent `PageRouteBuilder` that returns its child unchanged
only when Morph should provide all visible route movement.

The forward flight follows the route's push animation and duration. The return
flight follows its pop animation and reverse duration. Morph applies the
departing endpoint's curve to that route progress; the route supplies the clock,
while Morph supplies the visual easing. The departing Morph also supplies
`switchThreshold`, the transition builder, and the custom delegate.

## Observe the lifecycle

Lifecycle callbacks belong to the endpoint whose role their name describes:

1. The departing endpoint calls `onStart` when its flight starts.
2. After a completed flight, the arriving endpoint calls `onReceived`.
3. Immediately afterward, the departing endpoint calls `onEnd`.

On route pop, the endpoint in the closing route is now the departing endpoint.
An interrupted path does not report arrival or completion for a destination it
did not reach. If the flight reverses or is replaced, the replacement calls the
new departing endpoint's `onStart` and then follows the same normal completion
order for the endpoint it actually reaches.

When the platform disables animations before a flight starts, Morph shows the
destination immediately without lifecycle callbacks. If reduced motion becomes
enabled during a flight, Morph finishes immediately without calling
`onReceived` or `onEnd`; an earlier `onStart` remains called.

Use lifecycle callbacks for observation and follow-up effects, not to make the
destination correct or visible. Reduced motion can intentionally omit them.

## Build a custom flight

Use a `MorphFlightDelegate<T>` when the automatic visual is not appropriate.
The type parameter is the endpoint data your delegate interpolates.

```dart
class StatusFlightDelegate extends MorphFlightDelegate<Color> {
  const StatusFlightDelegate();

  @override
  Color properties(MorphEndpointContext endpoint) {
    return (endpoint.child as ColoredBox).color;
  }

  @override
  Color lerp(Color source, Color destination, double progress) {
    return Color.lerp(source, destination, progress)!;
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Color> flight) {
    return AnimatedBuilder(
      animation: flight.animation,
      builder: (context, child) {
        return ColoredBox(color: flight.properties);
      },
    );
  }
}
```

Use the same delegate runtime type and the same meaning for `T` at both
endpoints:

```dart
Morph(
  tag: 'status-surface',
  flightDelegate: const StatusFlightDelegate(),
  child: const ColoredBox(color: Colors.green),
)
```

Different instances of that delegate type may have different constructor
values. They still match; the departing delegate instance and its configuration
control that direction.

The delegate contract is:

1. `properties` reads each endpoint when the flight is captured. Resolve
   inherited values synchronously from `endpoint.context`; do not retain the
   context. The endpoint also exposes `child`, `localSize`, `overlayBounds`,
   `transform`, and `axisScale`.
2. `lerp` returns the current `T` for the curved animation progress. Progress
   can overshoot.
3. `buildFlight` builds the in-flight content. Morph positions and sizes the
   returned widget between the endpoint bounds. This method is not called on
   every progress change, so listen to `flight.animation` whenever the widget
   reads changing values.

`MorphFlight` exposes `source`, `destination`, `kind`, `animation`, the current
`properties`, and the current overlay-coordinate `bounds`. Incompatible custom
delegates do not run a custom flight; the destination remains visible normally.
Treat exceptions thrown by custom delegate methods like other widget errors;
Morph does not provide a recovery transition for invalid delegate code.

## Generic-content constraints

During a generic flight, Morph uses the departing endpoint's inherited themes
and `MediaQuery` before `switchThreshold`, then the arriving endpoint's values
after the content switch. Other inherited values introduced locally around an
endpoint are not transferred.

The live generic in-flight subtree must not contain a `GlobalKey` that is also
mounted at an endpoint. Wrap the affected subtree in a snapshot or hidden
`MorphDescendant` when it should stay mounted only at the endpoint. If the
subtree must instead remain live, use a custom delegate that returns an
independent visual: resolve the required inherited values in `properties`, and
do not rebuild the same keyed subtree in `buildFlight`.

Without an enclosing `Overlay`, Morph renders its child normally but cannot
transition. Endpoints in different overlays do not match. Avoid mounting more
than one logical shared element with the same tag in one overlay.

For exhaustive member contracts, see the
[Morph API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/Morph-class.html).
