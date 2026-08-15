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

Create and dispose the controller in the widget that owns the visibility
state. Calls made while a transition is running continue from the currently
visible state.

## Retain or unmount hidden content

Hidden content remains mounted by default, preserving its widget state and
layout. Set `unmount: true` when hidden content should be disposed instead:

```dart
ControlledVisibility(
  controller: visibilityController,
  unmount: true,
  child: const ExpensiveDetails(),
)
```

Unmounting trades state retention for lower hidden-tree memory use. Refer to
the [API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/ControlledVisibility-class.html)
for lifecycle callbacks, reduced-motion behavior, and timing defaults.
