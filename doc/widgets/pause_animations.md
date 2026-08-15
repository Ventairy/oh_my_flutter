# PauseAnimations

Use `PauseAnimations` when ticker callbacks in a subtree should be muted.

## Pause explicitly

The default constructor accepts `paused`, which defaults to `true`:

```dart
PauseAnimations(
  paused: isLoading,
  child: const ProgressWidget(),
)
```

## Pause temporarily

Use `PauseAnimations.temporarily` to enable callbacks automatically after a
fixed duration:

```dart
const PauseAnimations.temporarily(
  duration: Duration(milliseconds: 300),
  child: ProgressWidget(),
)
```

Flutter still advances elapsed ticker time while callbacks are muted, so child
animations catch up when they resume. A disabled ancestor `TickerMode` remains
in effect after `PauseAnimations` resumes its subtree.
