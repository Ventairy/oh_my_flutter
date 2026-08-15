# ControlledVisibility

Use `ControlledVisibility` when parent code should show or hide a child while
retaining control of its visual transition. Without a transition, visibility
changes immediately.

## Basic usage

```dart
final visibilityController = ControlledVisibilityController();

ControlledVisibility(
  controller: visibilityController,
  showDuration: const Duration(milliseconds: 240),
  hideDuration: const Duration(milliseconds: 120),
  showTransition: (child, animation) => FadeTransition(
    opacity: CurveTween(curve: Curves.easeOutCubic).animate(animation),
    child: child,
  ),
  hideTransition: (child, animation) => FadeTransition(
    opacity: animation,
    child: child,
  ),
  child: const Text('More details'),
);

visibilityController.show();
visibilityController.hide();
```

The animation represents visibility: show transitions receive `0` to `1`, and
hide transitions receive `1` to `0`.

The child starts hidden. Both durations default to 300 milliseconds, but a
duration is ignored when its direction has no transition. The controller does
not have a `dispose` method. Retain one instance in the parent and use it with
one mounted `ControlledVisibility` at a time; it can be attached to a later
widget after the current one unmounts.

Calls made before attachment are applied after the widget mounts. Calls made
while a transition is running continue from its current visual state. The
interrupted operation's completion future completes, but does not distinguish
interruption from normal completion.

## Retain or unmount hidden content

Hidden content remains mounted by default, preserving its widget state and
layout while disabling pointer input and semantics. Set `unmount: true` when
hidden content should be disposed instead:

```dart
ControlledVisibility(
  controller: visibilityController,
  unmount: true,
  child: const ExpensiveDetails(),
)
```

Unmounting trades state retention for lower hidden-tree memory use. Showing it
again creates a fresh child subtree before the show transition.

## Observe an operation

`onShow` and `onHide` run as soon as their command is requested. Each receives
a future that completes when the transition finishes, immediately when no
transition runs, or when a later command interrupts it. Reduced-motion
preferences skip the visual transition while preserving these callbacks and
completing their futures immediately.
