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

The duration must not be negative. Zero leaves ticker callbacks enabled.
Changing the duration restarts the temporary pause; rebuilding with the same
duration does not. The countdown begins when the widget mounts, and remounting
starts a new countdown.

`PauseAnimations` controls Flutter ticker callbacks through `TickerMode`. It
does not pause timers, futures, I/O, audio, or other application work. Flutter
still advances elapsed ticker time while callbacks are muted, so a child can
jump to its current elapsed position when animation callbacks resume. A
disabled ancestor `TickerMode` remains in effect after `PauseAnimations`
resumes its subtree.
