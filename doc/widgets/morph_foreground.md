# MorphForeground

Use `MorphForeground` for a control or other visual that should stay at its
resting position above a nearby Morph transition.

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
      child: MorphForeground(
        child: FilledButton(
          onPressed: () {},
          child: const Text('Continue'),
        ),
      ),
    ),
  ],
)
```

The child renders normally while no Morph transition affects its route. During
an applicable transition, its current visual state stays above the Morph flight
without moving between matched endpoints. Overflow such as shadows remains
visible. Place opacity, clipping, filters, and masks inside `MorphForeground`
when those effects must remain visible with the child during a flight.

`MorphForeground` does not need a tag. It applies to Morph flights associated
with the same route, including same-screen changes, route pushes, and route
pops. A foreground is not interactive during a flight and does not contribute
duplicate accessibility semantics. Interaction and semantics return when the
flight finishes.

Use `MorphForeground` only when content must remain visually above Morph. It is
not a general replacement for Flutter overlays and does not place content above
dialogs, menus, or unrelated overlay entries. Without an enclosing `Overlay`,
it displays its child normally.

See the
[MorphForeground API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/MorphForeground-class.html)
for the complete contract.
