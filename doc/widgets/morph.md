# Morph

`Morph` moves and resizes shared content between appearances, such as a card
and its details. Both appearances share the same stable `MorphTarget` instance.
A target defines their connection and optional forward and return timing.
Matching stays within one Flutter `Overlay`.

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
```

## Set up navigation and targets

Create one `MorphNavigatorObserver` for every Navigator containing Morphs.
Register it from the Navigator's first build and retain it across rebuilds:

```dart
// Fields in the State that owns the app.
final morphObserver = MorphNavigatorObserver();

// In build:
MaterialApp(
  navigatorObservers: [morphObserver],
  home: const HomePage(),
)
```

A nested Navigator needs its own observer; an observer on the outer Navigator
is insufficient. Do not share an observer between Navigators or add it after
navigation has started. Subclasses must call `super` in overridden observer
callbacks. Incorrect registration produces a descriptive debug assertion.

Local Morphs can also use an Overlay without a Navigator. Without any Overlay,
a Morph displays its child normally without transitions.

Create targets once in the owning State, not inside `build`:

```dart
late final target = MorphTarget(
  tag: widget.item.id,
  duration: const Duration(milliseconds: 400),
  reverseDuration: const Duration(milliseconds: 250),
  curve: Curves.easeOut,
  reverseCurve: Curves.easeIn,
);
```

Pass this same instance to both appearances, including through route
constructors when needed. Separate instances do not match, even with equal
tags. Targets require no disposal. The tag labels diagnostics; matching and status belong to the target instance.

## Configure another widget during a flight

Use `MorphNode` to configure how a child widget participates in a flight for a
`MorphTarget`. Give it the same target instance as the moving `Morph`. The child
keeps its normal layout position; during a matching flight, its visual is
projected into Morph's overlay and follows that position as the page scrolls.

```dart
MorphNode(
  target: target,
  child: detailBody,
)
```

`transitionBuilder` configures the projected visual during the flight. It
receives the flight's curved and uncurved animations. An ancestor route fade
does not automatically affect overlay content, so a page that fades its body
can pass its route animation explicitly:

```dart
MorphNode(
  target: target,
  transitionBuilder: (context, child, curved, uncurved) =>
      FadeTransition(opacity: routeAnimation, child: child),
  child: detailBody,
)
```

`zIndex` configures the child's paint order relative to the moving `Morph`:
negative values place it behind the flight (the default), and positive values
place it in front. The child remains interactive in its normal position. Its
projected visual does not receive input or duplicate accessibility semantics.

## Prefer one relationship and fall back to another

Pass alternatives in priority order on the destination:

```dart
Morph(
  targets: [specificTarget, fallbackTarget],
  child: content,
)
```

Morph chooses the destination's first usable match, even when the source lists
its targets in a different order. Each visual joins at most one flight. A
missing or incompatible first match allows the next alternative; an accepted
flight never starts a fallback after completion or cancellation. Without a
usable match, the content displays normally.

Supply at least one target and do not repeat instances in the
same list. Keep target instances stable and treat the list as immutable.
Reordering affects future matches without restarting an active flight. When
several arriving visuals compete for a source, earlier registered appearances
are considered first; the existing appearance-order rules still apply.

Each connection can have its own timing. For example, give a card both
`cardToDetails` and `cardToPreview`, then give details only `cardToDetails`
and preview only `cardToPreview`. The selected target supplies the flight's
duration and curve. Delegates and callbacks remain on each Morph.

## Restrict matching

Use `MorphTarget.canMatch` to allow only particular route relationships or
navigation operations. For example, allow shared flights on push and pop while
leaving replacement and removal navigation to the ordinary route transition:

```dart
late final target = MorphTarget(
  tag: widget.item.id,
  canMatch: (match) =>
      match.operation == MorphMatchOperation.push ||
      match.operation == MorphMatchOperation.pop,
);
```

The shared target checks each proposed pair once. A rejected
candidate allows the next destination target to be considered. Approval still
requires compatible, available endpoints. Exceptions are reported through
Flutter's error reporting and reject that candidate.

Use `Morph.canMatch` when a particular appearance needs narrower rules than
its shared targets. It receives the candidate target and the same match context:

```dart
Morph(
  targets: [previewTarget, itemTarget],
  canMatch: (target, match) =>
      target != previewTarget || match.operation == MorphMatchOperation.push,
  child: const Text('Preview item'),
)
```

The shared target's policy runs first, then the destination appearance's policy,
then the source appearance's policy. All must approve. A restriction on one
appearance does not change how other appearances use that target.

`sourceRoute` and `destinationRoute` are the actual Flutter routes. On pop, the
page being left is the source and the revealed route is the destination. A
`local` match has the same enclosing route on both sides, or null outside a
route. Navigation operations follow observer notifications: `push`, `pop`,
`replace` (including `pushReplacement`), or `remove`. Compound updates use the
operation responsible for the destination becoming current; `unknown` means
the notifications did not establish one.

Keep predicates synchronous and side-effect-free. A stable target can read
current policy through its callback. Each new navigation, including pop, checks
eligibility again. An accepted flight keeps its decision through gesture
reversal, completion, and cancellation. Changing policy alone neither starts
matching nor cancels a flight. Updating a child does not consult this predicate.

## Mount and remove appearances

Keep the card mounted and conditionally mount its details:

```dart
Stack(
  children: [
    Align(
      alignment: Alignment.topLeft,
      child: Morph(
        targets: [target],
        child: const Text('Item summary'),
      ),
    ),
    if (showDetails)
      Align(
        alignment: Alignment.bottomRight,
        child: Morph(
          targets: [target],
          child: const Text(
            'A complete item description',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
        ),
      ),
  ],
)
```

`setState(() => showDetails = true)` transfers the visual to details. Setting
it to false returns to the card. The appearance being left is the **departing
endpoint**; the one becoming current is the **arriving endpoint**.

The newest mounted eligible appearance becomes current. Removing it selects
the most recently mounted surviving appearance. Removing a covered appearance
does not change the current one. Rebuilds, child updates, and reparenting within
one frame preserve appearance order. Changing a Morph's target counts as a new
appearance even when Flutter reuses its State.

Several arrivals in one frame produce a flight directly to the last surviving
arrival. Intermediate appearances remain in their mounting order for later
returns. An arrival in a background route or a covered parent appearance does
not take the foreground visual. An interrupted flight continues from its
current appearance toward the latest destination.

Changing an `IndexedStack` index or `Offstage` alone does not request a
transition. Mount or remove a matching appearance to request one.
There is no additional view wrapper or activation call.

Custom delegates can include external content with
`MorphEndpointContext.groupSnapshot` (see grouped content below).

## Update content within one appearance

Changing a mounted Morph's child updates it normally without starting a flight.
To transition between replacement appearances, give the Morph widgets distinct
Flutter keys and the same target. Active flights can still follow a moving
destination through `MorphTarget.watchDestination` or retarget to a newly
mounted appearance.

## Choose the automatic behavior

The default `flightConfig` is `const MorphFlightConfig.auto()`. It chooses
the transition from the two children:

- Eligible `Text`, `Container`, `DecoratedBox`, and vertical `Column` pairs
  animate their supported visual values.
- Every other pair still moves and resizes between its endpoint rectangles,
  then replaces discrete content at `childSwitchAt`.
- If a supported widget arrangement is not eligible for specialization, Morph
  uses the generic behavior automatically. No eligibility check is required in
  application code.

Children inside matching `Column` endpoints correspond by their list position.
Flutter keys continue controlling widget identity at each endpoint but do not
change which Column children animate together.

Specialization is best-effort: supported values interpolate smoothly, while
unsupported or discrete values can switch. Use a custom delegate when a
particular property must follow an application-defined interpolation contract.

Configure automatic child replacement on `.auto()`:

```dart
Morph(
  targets: [itemTarget],
  flightConfig: .auto(childSwitchAt: 0.4),
  child: content,
)
```

The default `childSwitchAt` is `0.5` and its valid range is 0 to 1. Source
content is selected before that point, and destination content is selected at
that point and afterward. The value follows the flight's curved progress, so
`0.4` means 40% of elapsed time only when the curve is linear.

The departing endpoint supplies the automatic configuration. A custom flight
delegate defines its own interpolation and child transitions instead.

## Configure timing and ownership

| Setting                        | Default and ownership                                                                                                                                                                         |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MorphTarget.duration`         | Omitted values inherit from the departing Morph's nearest configured ancestor target. Without an inherited value, same-screen flights use 300 ms and route pushes follow the route animation. |
| `MorphTarget.reverseDuration`  | Defaults to `duration`. When both are omitted, reverse timing is inherited; without inherited timing, same-screen returns use 300 ms and route pops follow the route animation.               |
| `MorphTarget.curve`            | Omitted values inherit from the departing Morph's nearest configured ancestor target, falling back to `Curves.linear`.                                                                        |
| `MorphTarget.reverseCurve`     | Defaults to `curve`. When both are omitted, the departing Morph supplies inherited reverse easing, falling back to `Curves.linear`.                                                           |
| `MorphTarget.watchDestination` | `false`. Enable it when either endpoint in this connection can move, resize, or change captured visuals while it is a destination.                                                            |
| `flightConfig`                 | `const MorphFlightConfig.auto()`. Both endpoints must use automatic configuration or compatible custom delegates; the departing endpoint controls the flight.                                 |

Use `duration` and `curve` for a newly mounted appearance or route push. Use
`reverseDuration` and `reverseCurve` when removing that appearance or popping
the route. Omitting either reverse setting falls back to its forward setting.
When both settings for one value are omitted, the departing appearance supplies
the inherited value, so different ancestor configurations can give push and pop
different timing. A duration must not be negative. Zero completes the visual
transition immediately.

Curves that overshoot can produce progress outside the 0 to 1 interval. Custom
delegates should either support that extrapolation or clamp progress when their
visual values require it.

## Configure a descendant relative to its Morph

`MorphDescendant` configures how one descendant subtree participates in its
nearest ancestor `Morph`. Use it when that subtree needs to relate to the Morph
differently from the surrounding descendants. Its current `flightBehavior`
property controls how the subtree is represented during a flight.

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
  targets: [editorTarget],
  child: Container(
    decoration: const BoxDecoration(color: Colors.white),
    child: MorphDescendant(
      flightBehavior: MorphDescendantFlightBehavior.snapshot(),
      child: SingleChildScrollView(
        controller: descriptionScrollController,
        child: TextField(controller: descriptionController),
      ),
    ),
  ),
)
```

For automatic flights, the source snapshot remains visible before
`childSwitchAt`; the destination snapshot is visible at that point and afterward.
The endpoint behavior is selected at the same time, so matching endpoints may
deliberately use different behaviors.

When the selected target sets `watchDestination: true`, the destination
snapshot and its reserved size refresh while the flight is active. This keeps
the in-flight image aligned with destination layout changes without mounting a
second copy of the snapshotted subtree. The shared target applies this behavior
in both directions.

Rebuilds, layout changes, and paints that reach the `MorphDescendant` are
detected automatically, and several changes in one frame produce one refreshed
image. Content that repaints independently inside a nested repaint boundary
also stays current, but may require an image refresh on every watched frame.
Keep frequently changing captured regions small, or use `live` or `hide` when
their behavior is a better fit.

If that content has a notifier for every visual change that should appear during
the flight, use `MorphDescendantFlightBehavior.snapshot(changes: notifier)`.
Morph can then reuse the image between notifications. Keep the default when no complete notifier
exists: an unsignaled change will not appear in the flight image until the live
content takes over. Layout changes and updates to the descendant child remain
automatic.

Snapshot capture is bounded to avoid unbounded image memory on constrained
devices. If one capture batch is unusually large, an active watched flight
keeps its last coherent snapshot until the content becomes capturable again;
an initially oversized snapshot is empty. Reduce the total captured area or the
number of captured descendants, or use `live` or `hide` when that result is more
appropriate. Splitting content into separate descendants can isolate future
refreshes to the regions that changed, but it does not bypass the total capture
bound.

A snapshot is visual only: it does not accept input or animate its own internal
state during the flight. Content that Flutter cannot capture as an image, such
as a platform view, is empty during the flight. Use `hide` when an empty result
is required consistently across platforms.

Use `live` explicitly when a shared wrapper selects behavior dynamically:

```dart
MorphDescendant(
  flightBehavior: MorphDescendantFlightBehavior.live(),
  child: Text(expanded ? longDescription : shortDescription),
)
```

Use `hide` to reserve endpoint space without showing content:

```dart
MorphDescendant(
  flightBehavior: MorphDescendantFlightBehavior.hide(),
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

A `MorphFlightDelegate` owns the complete in-flight visual. For descendant
content used in a custom flight, [register the content](#register-descendant-content)
and build the returned widget.

## Animate a discrete content switch

Set `childTransition` on `.auto()` when discrete automatic content changes
should animate around `childSwitchAt`. This includes changed `Text` values,
generic widget pairs, and ordinary content inside specialized Container or
Column flights.
Nested `Morph` widgets continue their independent flights.

```dart
Morph(
  targets: [statusTarget],
  flightConfig: .auto(
    childSwitchAt: 0.4,
    childTransition: (child, animation) {
      return FadeTransition(opacity: animation, child: child);
    },
  ),
  child: Text(expanded ? 'Ready to publish' : 'Draft'),
)
```

For departing content, the supplied animation moves from 1 to 0. For arriving
content, it moves from 0 to 1. Without a builder, content switches immediately
at `childSwitchAt`. Configure the builder on both endpoints when the same
treatment should apply during both forward and reverse flights.

## Follow a moving destination

Set `watchDestination: true` on the shared target when either endpoint can move
or resize while a flight travels toward it, for example while keyboard insets
change:

```dart
final continueTarget = MorphTarget(
  tag: #continue,
  watchDestination: true,
);

Morph(
  targets: [continueTarget],
  child: const ContinueButton(),
)
```

The flight follows its destination until it finishes. Geometry, custom delegate
properties, grouped content, and descendant snapshots update together, so the
flight never exposes a partially refreshed endpoint. A custom delegate's
`properties` method may therefore run again; keep it synchronous and free of
side effects.

The target represents the whole connection, so watching applies to the current
destination in both directions. Leave it disabled when destinations remain
stationary.

## Coordinate nested Morphs

An omitted forward duration or curve inherits the forward value from the
departing appearance's nearest Morph ancestor. An omitted reverse setting first
falls back to the selected target's forward setting; when the target omits both,
it inherits the ancestor's effective reverse value. Inherited values can differ
when the two appearances have different ancestors.

```dart
final target = MorphTarget(
  tag: 'card',
  duration: const Duration(milliseconds: 500),
  reverseDuration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInCubic,
);

Morph(
  targets: [target],
  child: Column(
    children: [
      Morph(targets: [titleTarget], child: const Text('Title')),
      Morph(targets: [actionTarget], child: const Icon(Icons.arrow_forward)),
    ],
  ),
)
```

The nested flights inherit 500 milliseconds and `Curves.easeOutCubic` when
moving forward, then 300 milliseconds and `Curves.easeInCubic` when returning.
Supply a setting on the nested Morph's target only when that flight should
intentionally use different timing. An inherited duration also gives a nested
route flight its own timing instead of the route's timing.

## Animate across routes

Put one endpoint in the current route and the matching endpoint in the route
being opened. Both routes must use the same navigator overlay.

```dart
// Field in the source State.
final routeSource = MorphTarget(tag: 'route-title');

// Source in build.
Morph(
  targets: [routeSource],
  child: const Text('Item summary'),
)

// Pass the same target to the new route.
Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (context) {
      return Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: Morph(
            targets: [routeSource],
            child: const Text('Full item description'),
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

When the shared target and the departing Morph ancestors' targets omit both
durations, the forward flight follows the route's push animation and the return
flight follows its pop animation. Morph applies the effective target curve to
that route progress, including gesture-controlled progress.

Set `MorphTarget.duration` when a route push should use the target's timing. Set
`reverseDuration` when a route pop should use different timing. Setting only
`reverseDuration` leaves the push on the route animation. A target-timed Morph
can finish and hand off while the page transition continues, or remain in the
navigator overlay after the page transition settles. Inherited durations have
the same effect. When returning beneath a closing route's colored modal barrier,
the shared visual stays at its destination until that route disappears. This
prevents a brief tint at landing without changing the route duration.

If a route-driven push reverses before the Morph finishes and
`reverseDuration` is configured, the Morph returns from its exact current
progress using that return duration. Cancelling a target-timed pop similarly
uses the forward duration to restore the current route. The remaining playback
time is proportional to the distance still to travel. An interrupted flight
starts the new direction's curve from its current visible state, so a rapid
return uses `reverseCurve` without jumping. A Morph that already handed off
starts a new return flight.

The departing Morph still supplies the flight delegate configuration.

Navigation matches only the actual departing and arriving routes. An
unmatched route between two matching routes breaks that relationship;

A back gesture previews the return. Completing it accepts the previous
appearance; cancelling it returns to the current route. A gesture with no
movement does not start a flight or invoke lifecycle callbacks.

### Use a router

For GoRouter, retain the observer with the router and supply it through the
router's `observers`. Each `ShellRoute` Navigator that contains Morphs needs its
own observer too. Use pages with a route animation when omitted target durations
should follow route progress:

```dart
late final router = GoRouter(
  observers: [morphObserver],
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: const HomePage(),
      ),
    ),
  ],
);
```

This example also imports `package:go_router/go_router.dart`. Install GoRouter
in the consuming application when using it. Matching never crosses Overlay
boundaries, including separate branch Navigators; switching GoRouter branches
does not animate between them.

## Observe the lifecycle

Lifecycle callbacks belong to the endpoint whose role their name describes:

1. The departing endpoint calls `onStart` when its flight starts.
2. After a completed flight, the arriving endpoint calls `onReceived`.
3. Immediately afterward, the departing endpoint calls `onEnd`.

On route pop, the endpoint in the closing route is now the departing endpoint.
An interrupted path does not report arrival or completion for a destination it
did not reach. A replacement flight calls its departing endpoint's `onStart`
and follows the completion order for the endpoint it actually reaches.
Reversing an existing route flight continues that flight's lifecycle without
calling `onStart` again.

When the platform disables animations before a flight starts, Morph shows the
destination immediately without lifecycle callbacks. If reduced motion becomes
enabled during a flight, Morph finishes immediately without calling
`onReceived` or `onEnd`; an earlier `onStart` remains called.

Use lifecycle callbacks for observation and follow-up effects, not to make the
destination correct or visible. Reduced motion can intentionally omit them.

## Build a custom flight

Read `MorphEndpointContext.target` in `properties` when different target
alternatives need different flight visuals. It identifies the candidate being
considered, including during fallback to another target. Capture the selected
visual values in the returned properties; approval and successful capture are
still required before the flight starts.

Subclass `MorphFlightDelegate<T>` when the automatic visual is not
appropriate, then pass an instance to `MorphFlightConfig.custom`. The type
parameter is the endpoint data your delegate interpolates.

```dart
class StatusFlightDelegate extends MorphFlightDelegate<Color> {
  const StatusFlightDelegate();

  @override
  Color properties(MorphEndpointContext endpoint) {
    return (endpoint.child as ColoredBox).color;
  }

  @override
  Color lerpProperties(Color source, Color destination, MorphFlightProgress progress) {
    return Color.lerp(source, destination, progress.curvedProgress)!;
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Color> flight) {
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
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
  targets: [statusTarget],
  flightConfig: const .custom(StatusFlightDelegate()),
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
   `transform`, and `axisScale`. Register endpoint widget content with
   `endpoint.descendantWidget(...)` and store the returned widgets in
   your properties.
2. `lerpProperties` returns the current `T` from a `MorphFlightProgress`.
   Use `curvedProgress` to follow the surface and `uncurvedProgress` to apply
   independent content timing. Curved progress can overshoot.
3. `buildFlight` builds the in-flight content. Morph positions and sizes the
   returned widget between the endpoint bounds. This method is not called on
   every progress change, so listen to `flight.curvedAnimation` when the widget
   reads changing properties or bounds. Listen to `flight.uncurvedAnimation`
   when content needs its own timing and easing.

`MorphFlight` provides the endpoint values, the reason for the transition,
and its current properties and overlay-coordinate bounds. Incompatible custom
delegates do not run a custom flight; the destination remains visible normally.
Treat exceptions thrown by custom delegate methods like other widget errors;
Morph does not provide a recovery transition for invalid delegate code.

### Choose animation progress

Use `curvedAnimation` to follow the current direction's target curve, which
also controls `bounds`. Use `uncurvedAnimation` to give custom content its own
intervals and curves. Both follow the same flight, including changes in
direction.

For example, this replacement for the delegate's `buildFlight` fades its visual
in during the first quarter of the uncurved progress. The color continues to
follow the Morph curve:

```dart
@override
Widget buildFlight(BuildContext context, MorphFlight<Color> flight) {
  return FadeTransition(
    opacity: flight.uncurvedAnimation.drive(
      CurveTween(curve: const Interval(0, 0.25, curve: Curves.easeIn)),
    ),
    child: AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, child) => ColoredBox(color: flight.properties),
    ),
  );
}
```

With an explicit 400 ms target duration, that fade takes 100 ms during
uninterrupted forward playback. When Morph follows a route animation,
`uncurvedAnimation` follows the route's progress. That progress may already
be curved or controlled by a gesture, so an interval does not necessarily
correspond to a fixed elapsed time.

When migrating a custom delegate, rename `lerp` overrides and calls to
`lerpProperties`, and replace `flight.animation` with
`flight.curvedAnimation`. If you construct `MorphFlight` yourself, supply both
`curvedAnimation` and `uncurvedAnimation`; there is no `animation` alias.

Inside `lerpProperties`, applying a curve to `progress.uncurvedProgress` gives
content independent timing without applying Morph's curve twice:

```dart
@override
Color lerpProperties(
  Color source,
  Color destination,
  MorphFlightProgress progress,
) => Color.lerp(
  source,
  destination,
  Curves.easeIn.transform(progress.uncurvedProgress),
)!;
```

Return the visible content values from `lerpProperties` so an interrupted
transition continues from those values. `flightKind` describes why the flight
started; an unfinished push playing backward remains `routePush`.
`animationStatus` describes the underlying flight animation, not its route:
a fresh `routePop` can have `AnimationStatus.forward` because it travels from
its outgoing endpoint toward its returning endpoint. These fields report
playback; they do not select a reverse curve for your delegate.

For existing custom delegates, replace the `double` argument of
`lerpProperties` with `MorphFlightProgress` and use `progress.curvedProgress`
where the old numeric argument was used. Apply the same migration to direct
calls and `MorphChildFlightDelegate.lerp`; all progress fields are required.

### Register descendant content

Use `endpoint.descendantWidget(child)` for endpoint widget content in
custom flights. Registration is the standard approach and is highly recommended
for better compatibility. Content may work without it.

Call the method during `properties`, store its returned `Widget`, and build
that widget in the flight. Register the complete subtree you want to use,
including any `MorphDescendant` wrappers. For example, this delegate keeps the
source content visible until 80% progress:

```dart
class ContentFlightDelegate extends MorphFlightDelegate<Widget> {
  const ContentFlightDelegate();

  @override
  Widget properties(MorphEndpointContext endpoint) {
    return endpoint.descendantWidget(endpoint.child);
  }

  @override
  Widget lerpProperties(Widget source, Widget destination, MorphFlightProgress progress) {
    return progress.curvedProgress < 0.8 ? source : destination;
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) {
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, child) => flight.properties,
    );
  }
}
```

The return type is an ordinary `Widget`. Your delegate's `T` can still be any
type: a record, your own class with `Widget` fields, or another property shape.
Register each piece that you want to select independently. For example, a
card's title can switch at 25% while its body keeps the source until 75%:

```dart
@override
({Widget title, Widget body}) lerpProperties(
  ({Widget title, Widget body}) source,
  ({Widget title, Widget body}) destination,
  MorphFlightProgress progress,
) {
  return (
    title: progress.curvedProgress < 0.25 ? source.title : destination.title,
    body: progress.curvedProgress < 0.75 ? source.body : destination.body,
  );
}
```

In that delegate's `properties`, register the title and body subtrees separately
and store the returned widgets in the corresponding fields. In `buildFlight`,
place `flight.properties.title` and `flight.properties.body` in your layout.

To crossfade the complete endpoints in the first example, replace `buildFlight`
with ordinary Flutter transitions:

```dart
@override
Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) {
  return Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(
        opacity: ReverseAnimation(flight.uncurvedAnimation),
        child: flight.source.properties,
      ),
      FadeTransition(
        opacity: flight.uncurvedAnimation,
        child: flight.destination.properties,
      ),
    ],
  );
}
```

Always build the returned widget and use it only in its associated flight.
Do not retain the endpoint context to register content after `properties`
returns.

## Generic-content constraints

During a generic flight, Morph uses the departing endpoint's inherited themes
and `MediaQuery` before `childSwitchAt`, then the arriving endpoint's values
after the content switch. Other inherited values introduced locally around an
endpoint are not transferred.

The live generic in-flight subtree must not contain a `GlobalKey` that is also
mounted at an endpoint. Wrap the affected subtree in a snapshot or hidden
`MorphDescendant` when it should stay mounted only at the endpoint. If the
subtree must instead remain live, use a custom delegate that returns an
independent visual: resolve the required inherited values in `properties`, and
do not rebuild the same keyed subtree in `buildFlight`.

Without an enclosing `Overlay`, Morph renders its child normally but cannot
transition. Endpoints in different overlays do not match. Use a separate target instance for each independent shared element.

For exhaustive member contracts, see the
[Morph API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/Morph-class.html).

## Observe a target during navigation

Read `target.status.value` for the current navigation result, or listen for
changes. The same target returns the same read-only listenable, including when
accessed before its appearances are mounted. Separate targets have independent
status even when their tags are equal.

```dart
final status = target.status;
final current = status.value;

void onStatusChanged() {
  final current = status.value;
  // Update your presentation for the current status.
}

status.addListener(onStatusChanged);
// Remove the listener when its owner is disposed.
status.removeListener(onStatusChanged);
```

You can also pass `target.status` to a `ValueListenableBuilder<MorphTagStatus>`.
Keep the Morph observer installed from Navigator creation, including when using
a router. Targets that have never been attached remain idle.

| Status      | Meaning                                                           |
| ----------- | ----------------------------------------------------------------- |
| `idle`      | No navigation has been evaluated yet.                             |
| `pending`   | Morph is resolving the appearances for the latest navigation.     |
| `unmatched` | No usable flight was accepted.                                    |
| `flying`    | A flight was accepted and is active, including its final handoff. |
| `completed` | The flight handed off at the navigation destination.              |
| `cancelled` | An accepted flight ended without completing that navigation.      |

The result remains available after completion or cancellation. A new navigation
starts a fresh resolution; the result does not describe a particular older
route or local appearance transition. A gesture that starts returning and
then cancels resolves as cancelled after its accepted flight settles. A gesture
that never moves does not start a new resolution. An immediate flight can finish
without listeners observing a separate flying notification.

For a custom route that transforms when possible and otherwise slides, keep its
destination laid out at its resting position but concealed while pending. Use
the normal slide only for unmatched; flying, completed, and cancelled must not
start a second transition. Keep the endpoints available during the destination's
initial layout. Reading this API does not conceal, position, or animate the route
for you.

Disabled animations also produce unmatched when no flight starts. Honor reduced
motion before selecting an animated fallback. When a newer navigation begins,
an older route must not reinterpret that newer result as its own fallback.

The returned listenable supports `.value`, `addListener`, `removeListener`, and
`ValueListenableBuilder`. It is owned by the target; remove your listeners rather than
disposing it. Notifications report current values and may combine changes that
happen within the same event-loop turn.

## Inherited configuration with MorphScope

Use `MorphScope` to provide configuration to Morph widgets in a subtree without
configuring each appearance individually.

### Enable or disable new flights

Set `enabled` to control whether descendants can start new Morph flights:

```dart
MorphScope(
  enabled: allowSharedTransitions,
  child: content,
)
```

Morph is enabled by default. Both endpoints must be enabled for a new flight.
A disabled outer scope takes precedence over an enabled inner scope. Disabled
content remains mounted and displays normally; same-screen changes and child
replacements apply without starting a flight. Re-enabling allows future flights
without replaying skipped changes.

An ongoing flight keeps its normal completion, reversal, retargeting, and
handoff behavior even after its scope is disabled. Scope changes do not cancel
flights. Normal removal, reduced-motion, and navigation behavior still apply.

The updated scope must rebuild before navigation that should use its new value.
Changing a boolean and immediately navigating in the same callback does not
ensure the scope has updated. A new navigation without an eligible flight
reports `MorphTagStatus.unmatched`; an ongoing flight retains its normal status
lifecycle.

## Register grouped content

Use `endpoint.groupSnapshot(link)` inside a custom delegate's
`properties` method when the flight includes widgets outside the Morph subtree.
Build the returned widget in that flight and apply content effects to it as one
composition. Give each endpoint its own stable `GroupLink`.

Declare that link in the delegate's `contentGroups` so external members follow
the endpoint's visibility from their first frame:

```dart
@override
Iterable<GroupLink> get contentGroups => [contentLink];

@override
Widget properties(MorphEndpointContext endpoint) =>
    endpoint.groupSnapshot(contentLink);
```

The endpoint rectangle defines the snapshot's coordinate frame. Morph manages
capture, original visibility, and disposal; independently transitioning nested
Morphs are excluded from the enclosing snapshot. If the group cannot be
captured, Morph settles without a snapshot flight.

See [Group](group.md) for membership, snapshot ordering, and standalone captures.
