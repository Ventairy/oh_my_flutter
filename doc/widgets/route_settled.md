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
  child: const CloseButton(),
)
```

`RouteSettled` has no built-in visual treatment. Provide either directional
transition only when the application needs one. Showing takes 300 milliseconds
by default when a show transition exists; hiding is immediate by default.
Without an enclosing route, the child is treated as settled and shown.
