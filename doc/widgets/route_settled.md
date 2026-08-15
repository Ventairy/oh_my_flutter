# RouteSettled

Use `RouteSettled` for controls or route chrome that should appear only after
the current route finishes moving and while no navigator gesture is active.

## Basic usage

```dart
RouteSettled(
  showTransition: (child, animation) => FadeTransition(
    opacity: animation,
    child: child,
  ),
  hideTransition: (child, animation) => FadeTransition(
    opacity: animation,
    child: child,
  ),
  showDuration: const Duration(milliseconds: 240),
  hideDuration: const Duration(milliseconds: 120),
  child: const CloseButton(),
)
```

`RouteSettled` has no built-in visual treatment. Supply `showTransition`,
`hideTransition`, or both when that visibility change should animate. Showing
takes 300 milliseconds by default when a show transition exists; hiding is
immediate by default. Without an enclosing route, the child is treated as
settled and shown.

The child is visible only when the nearest enclosing `ModalRoute` has completed
its animation and the nearest `Navigator` has no user gesture in progress. It
hides while that route leaves or an interactive navigation gesture is active.
If a gesture is canceled and the route settles again, the show behavior runs
again.

Hidden content stays mounted and keeps its layout, but cannot receive pointer
input and is excluded from semantics. Reduced-motion preferences apply the
same visibility rule without running the supplied transition.
