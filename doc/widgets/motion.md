# Motion

Wrap a widget with `Motion` to apply a reusable visual effect without changing
the child's layout.

## Apply an effect

```dart
const Motion(
  effect: FloatingMotionEffect(
    delay: Duration(milliseconds: 300),
  ),
  child: Icon(Icons.cloud_outlined),
)
```

Effects own their configuration; `Motion` owns playback and respects the
platform's reduced-motion preference. Built-in effects can fade, scale, move,
or continuously float a widget:

```dart
const Motion(
  effect: FadeInMotionEffect(),
  child: Text('Ready'),
)

const Motion(
  effect: ScaleInMotionEffect(scale: 0.6),
  child: Icon(Icons.check),
)

const Motion(
  effect: MoveMotionEffect(
    begin: Offset(-24, 0),
    end: Offset.zero,
  ),
  child: Icon(Icons.arrow_forward),
)
```

## Combine effects

Use `Motion.list` to run effects concurrently or stagger them with independent
delays:

```dart
const Motion.list(
  effects: [
    FadeInMotionEffect(),
    ScaleInMotionEffect(
      scale: 0.6,
      delay: Duration(milliseconds: 80),
    ),
  ],
  child: Text('Ready'),
)
```

The first effect is applied first, and each following effect composes around
the result. Keep the effects list immutable after passing it to `Motion.list`.

## Lifecycle and interaction

`onStart` runs after an effect's delay. `onEnd` runs when a one-shot effect
completes. Looping effects do not call `onEnd` while mounted, and canceled or
disposed effects are not reported as completed.

```dart
Motion(
  effect: FadeInMotionEffect(
    onStart: handleMotionStarted,
    onEnd: handleMotionCompleted,
  ),
  child: const Text('Ready'),
)
```

Pointer interaction is ignored by default while any effect is waiting or
playing. Set `interactive: true` to accept input during playback. A looping
effect otherwise keeps interaction disabled while mounted.

Reduced-motion one-shot effects call `onStart` followed immediately by
`onEnd`. `FloatingMotionEffect` exposes only `onStart` because it does not
complete.

## Create a custom effect

Extend `MotionEffect` for a reusable one-shot or looping effect. The same effect
works with `Motion` and `TextMotion`.

```dart
class SlideInMotionEffect extends MotionEffect {
  const SlideInMotionEffect()
    : super(duration: const Duration(milliseconds: 240));

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.translate(x: 24 * (1 - progress), y: 0);
  }
}
```

One-shot effects run once per mounted `Motion`; assign a new key to replay one.
Looping effects should render equivalent states at progress 0 and 1 so their
cycles remain seamless.
