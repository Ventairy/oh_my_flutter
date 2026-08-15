# Sequence

Use `Sequence` for an ordered flow that displays one child at a time. Its
controller supports sequential and indexed navigation and exposes the selected
index for controls and progress indicators.

## Basic usage

```dart
final sequenceController = SequenceController();

Sequence(
  controller: sequenceController,
  alignment: AlignmentDirectional.topStart,
  nextTransition: (child, animation) => FadeTransition(
    opacity: animation,
    child: child,
  ),
  previousTransition: (child, animation) => ScaleTransition(
    scale: animation,
    child: child,
  ),
  children: const [
    Text('Account'),
    Text('Preferences'),
    Text('Review'),
  ],
);

sequenceController.next();
sequenceController.previous();
sequenceController.goTo(2);
```

Dispose a controller created by the parent when that parent is disposed.
Navigation is immediate when its directional transition is omitted.

## Preserve inactive state

Set `keepMounted: true` only when inactive steps must preserve local widget
state. Retained steps stay in memory and are still laid out offstage. With the
default `false`, only the current and transitioning steps are mounted.

## Size and alignment

During a transition, differently sized steps share the largest participant's
size and use `alignment`, which defaults to the directional top-start. A parent
such as `Center` can still move the whole `Sequence` as that outer size changes;
use stable parent constraints when the sequence needs a fixed external anchor.
For low-end devices, prefer lightweight transitions such as fade, slide, and
scale.
