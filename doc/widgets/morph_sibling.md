# MorphSibling

`MorphSibling` lets other widget outside a Morph's subtree
accompany that appearance. For example, a card header can fade out while a
details header fades in as the shared surface moves between them.

Follow the [Morph setup](morph.md#set-up-navigation-and-targets), including a
stable `MorphNavigatorObserver` on each owning Navigator.

## Associate an external widget

Create one target per appearance in State. Give its Morph and siblings the
exact same target instance:

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

// State fields, created once.
final card = MorphTarget(tag: 'surface');
final details = MorphTarget(tag: 'surface');

// In build:
Stack(
  children: [
    Morph(
      target: card,
      child: Container(color: Colors.white),
    ),
    Align(
      alignment: Alignment.bottomCenter,
      child: MorphSibling(
        target: card,
        child: FilledButton(
          onPressed: () {},
          child: const Text('Continue'),
        ),
      ),
    ),
  ],
)
```

Equal tags allow different Morph appearances to match. A sibling's association
is more specific: it must use the same instance as its Morph. Any number of
siblings can accompany one target.

By default, the sibling's live visual paints directly above the matching flight
without moving between endpoints. Overflow such as shadows stays visible.
Later flights with other tags remain above it. Siblings of the arriving target
paint above the departing target's siblings; siblings of one target keep their
registration order.

## Animate arrival and departure

Add `transitionBuilder` to respond to the appearance's progress:

```dart
MorphSibling(
  target: details,
  transitionBuilder: (child, curved, uncurved) {
    return FadeTransition(opacity: uncurved, child: child);
  },
  child: const Text('Details header'),
)
```

The builder receives curved progress that follows `Morph.curve` and uncurved
progress unaffected by that curve. Both animations are clamped to 0–1. The
values belong to the target's appearance, including when both appearances are
on the same route:

| Transition         | Card header | Details header |
| ------------------ | ----------- | -------------- |
| Card → details     | 1 → 0       | 0 → 1          |
| Details → card     | 0 → 1       | 1 → 0          |
| Resting on details | 0           | 1              |
| Resting on card    | 1           | 0              |

Mounting details makes them current. Removing them returns to the most recently
mounted surviving appearance. Earlier mounted siblings remain at 0 after a
flight settles; the current appearance's siblings remain at 1.

Replacing only the current target's Morph child does not replay its headers.
They stay visible, or continue their existing arrival or departure. When
another appearance interrupts a flight, all participating siblings continue
from their current curved and uncurved values, including outgoing appearances
from earlier flights.

The animation objects remain stable across ordinary rebuilds and callback
replacements. Pass them to Flutter transition widgets or use builder logic to
choose the visual effect. Omitting `transitionBuilder` leaves the child visually
unchanged throughout the flight.

For independent intervals, apply your own curve to uncurved progress. When
following a route, that progress may already be eased or controlled by a
gesture, so it is not necessarily linear elapsed time.

## Keep headers mounted for a visible exit

Removing a sibling disposes it normally. Morph does not keep a removed header
alive to finish its exit. Keep both headers mounted while their departure and
arrival should be visible; each uses its own target:

```dart
Row(
  children: [
    MorphSibling(
      target: card,
      transitionBuilder: (child, curved, uncurved) =>
          FadeTransition(opacity: uncurved, child: child),
      child: const Text('Card header'),
    ),
    MorphSibling(
      target: details,
      transitionBuilder: (child, curved, uncurved) =>
          FadeTransition(opacity: uncurved, child: child),
      child: const Text('Details header'),
    ),
  ],
)
```

Switching an `IndexedStack` index or changing `Offstage` alone is not a Morph
transition request. Use the supported mounting, removal, target-replacement,
or child-replacement behavior described in the [Morph guide](morph.md).

## Choose paint order

Set `paintOnTop` to false to animate in the normal widget-tree paint order:

```dart
MorphSibling(
  target: details,
  paintOnTop: false,
  transitionBuilder: (child, curved, uncurved) {
    return ScaleTransition(scale: curved, child: child);
  },
  child: const Text('Details'),
)
```

An in-place sibling keeps its normal pointer and accessibility behavior during
the flight. An above-Morph sibling is non-interactive during the flight and
does not contribute duplicate accessibility semantics; both return to ordinary
widget-tree behavior when the flight finishes.

`MorphSibling` does not place content above dialogs, menus, or unrelated overlay
entries. Without an enclosing Overlay, it displays its settled state normally.

See the
[MorphSibling API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/MorphSibling-class.html)
for the complete contract.
