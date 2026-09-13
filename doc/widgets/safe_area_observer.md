# SafeAreaObserver

Measure the unsafe screen-edge overlap of a region without changing its content.
Use this when a surface needs to coordinate its own spacing or scrolling around
system controls. Use `MaybeSafeArea` to move compact content automatically, or
Flutter's `SafeArea` for ordinary layout padding.

## Observe a region

Create a `SafeAreaObserverHandle` in the owning State, attach it to one observer,
and dispose it with that State:

```dart
import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class ObservedPanel extends StatefulWidget {
  const ObservedPanel({required this.child, super.key});

  final Widget child;

  @override
  State<ObservedPanel> createState() => _ObservedPanelState();
}

class _ObservedPanelState extends State<ObservedPanel> {
  final handle = SafeAreaObserverHandle();

  @override
  void dispose() {
    handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeAreaObserver(handle: handle, child: widget.child);
  }
}
```

`handle.avoidanceInsets` is null until usable geometry is available, and after
removal. A measured region already inside the safe screen area returns
`EdgeInsets.zero`. All four edges are measured independently, so a full-screen
region can report both top and bottom overlap. Disable individual edges with
`left`, `top`, `right`, and `bottom`.

Insets use local logical units: a region scaled to twice its size reports
half the screen-space overlap. Measurements describe its rectangular screen
bounds; they are not a contour or an exact clearance solution for rotated,
skewed, or perspective-transformed content. Offscreen distance is never added
to an unsafe band's overlap.

## Respond to changes

Read live insets during painting or interaction. Add a listener to cache values
for subsequent layout or rebuilds. Listeners receive the first available result,
changed measurements, and loss of geometry after a frame. Multiple changes in
one frame are combined, and unchanged values do not repeatedly notify.

These notifications cannot reflow a frame that has already completed. Do not
read live geometry during build or layout, and do not assume that a listening
padding widget will update in the same frame as an ancestor's movement.

Observe a stable outer region around a scrolling viewport. Measuring the
scrolling child instead changes the reported overlap as that child moves and
can create unwanted feedback when the result changes its own layout.

## Choose the unsafe region

The observer reads `MediaQuery.padding` and does not consume it for descendants.
It does not include keyboard insets automatically. When needed, supply a scoped
`MediaQuery` with the desired padding and restore the original data around the
content. This lets the surface choose its keyboard policy independently.

See the [API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/SafeAreaObserver-class.html)
for the complete contract.
