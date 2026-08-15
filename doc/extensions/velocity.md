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
method accepts a minimum primary-axis velocity. Axis dominance is required by
default so an equal or stronger diagonal component does not qualify.

```dart
final shouldAdvance = details.velocity.isSwipeLeft(
  minVelocity: 900,
  requireHorizontalDominance: false,
);
```

These methods classify velocity only. The consuming interaction remains
responsible for distance, progress, and whether the action is allowed.
