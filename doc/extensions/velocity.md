# Velocity classification

Use `VelocityExtension` at a drag boundary when release speed and direction
should help decide whether an interaction completes.

```dart
void handleDragEnd(DragEndDetails details) {
  if (details.velocity.isSwipeDown()) {
    dismiss();
  }
}
```

The extension classifies upward, downward, leftward, and rightward swipes. Each
method accepts a minimum primary-axis velocity, which defaults to 700 logical
pixels per second. A speed exactly equal to the threshold qualifies.

Axis dominance is required by default. The absolute primary-axis speed must be
strictly greater than the other axis, so an equal or stronger diagonal
component does not qualify.

```dart
final shouldAdvance = details.velocity.isSwipeLeft(
  minVelocity: 900,
  requireHorizontalDominance: false,
);

final shouldDismiss = details.velocity.isSwipeDown(
  minVelocity: 900,
  requireVerticalDominance: false,
);
```

These methods classify velocity only. The consuming interaction remains
responsible for distance, progress, and whether the action is allowed.
Supply a finite, non-negative `minVelocity`. A zero velocity never qualifies,
even when the threshold is zero, because it has no requested direction.
