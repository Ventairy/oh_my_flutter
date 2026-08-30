# MorphSibling

Use `MorphSibling` to coordinate a control or other widget outside a `Morph`
subtree with that Morph's active transition.

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Stack(
  children: [
    Morph(
      tag: 'surface',
      child: Container(color: Colors.white),
    ),
    Align(
      alignment: Alignment.bottomCenter,
      child: MorphSibling(
        tag: 'surface',
        child: FilledButton(
          onPressed: () {},
          child: const Text('Continue'),
        ),
      ),
    ),
  ],
)
```

The sibling's `tag` must match the related `Morph`. While no matching flight is
active, the child renders normally. By default, its live visual paints directly
above the matching flight without moving between endpoints. Overflow such as
shadows remains visible, while later flights with other tags stay above it.

Add `transitionBuilder` when the sibling should respond visually to the Morph:

```dart
MorphSibling(
  tag: 'surface',
  transitionBuilder: (child, animation) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.8, 1),
      ),
      child: child,
    );
  },
  child: const Text('Details'),
)
```

The animation uses the matching Morph's curved visual progress, clamped between
0 and 1. It advances as the sibling's route appears, reverses as that route
departs, and stays at 1 while no matching flight is active. Consumers can use
any transition widget or builder logic; omitting `transitionBuilder` keeps the
sibling visually unchanged throughout the flight.

Set `paintAboveMorph` to false when the sibling should animate without changing
its normal paint order:

```dart
MorphSibling(
  tag: 'surface',
  paintAboveMorph: false,
  transitionBuilder: (child, animation) {
    return ScaleTransition(scale: animation, child: child);
  },
  child: const Text('Details'),
)
```

An in-place sibling keeps its normal pointer and accessibility behavior during
the flight. An above-Morph sibling is non-interactive while projected and does
not contribute duplicate accessibility semantics; both return to ordinary
widget-tree behavior when the flight finishes.

Matching includes same-screen changes, route pushes, and route pops. Morphs
with other tags do not animate or project the sibling.

`MorphSibling` is not a general replacement for Flutter overlays and does not
place content above dialogs, menus, or unrelated overlay entries. Without an
enclosing `Overlay`, it displays the settled transition state normally.

See the
[MorphSibling API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/MorphSibling-class.html)
for the complete contract.
