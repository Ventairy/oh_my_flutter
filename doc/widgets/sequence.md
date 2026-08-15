# Sequence

Use `Sequence` for an ordered flow with one selected child. During an animated
change, the outgoing and incoming children can be visible together. Its
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
Only one `Sequence` can use a controller at a time. Calling navigation methods
before attachment or after detachment throws `StateError`.

At least one child is required. A transition builder wraps both the outgoing
and incoming child. The incoming animation runs from `0` to `1`, while the
outgoing animation runs from `1` to `0`.

The first child is selected initially. `next` at the last child, `previous` at
the first child, and `goTo` for the current index do nothing. An invalid index
throws `RangeError`. The selected `index` and its listeners update when
navigation starts. A new command during a transition takes effect immediately;
commands are not queued.

Navigation is immediate when its directional transition is omitted. Moving to
any higher index uses `nextTransition`; moving to any lower index uses
`previousTransition`. Reduced-motion preferences also switch immediately.

## Preserve inactive state

Set `keepMounted: true` only when inactive steps must preserve local widget
state. Retained steps stay in memory and are still laid out offstage. With the
default `false`, only the current and transitioning steps are mounted.

## Size and alignment

During a transition, differently sized incoming and outgoing steps share their
largest size and use `alignment`, which defaults to the directional top-start.
A parent such as `Center` can still move the whole `Sequence` as that outer
size changes; use stable parent constraints when the sequence should stay in
one place while its content changes size.
For low-end devices, prefer lightweight transitions such as fade, slide, and
scale.
