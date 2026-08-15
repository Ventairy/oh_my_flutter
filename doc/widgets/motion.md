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
or continuously float a widget. Unless a constructor documents another value,
effects start immediately, last 300 milliseconds, use `Curves.linear`, and run
once:

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
Each effect keeps its own delay, timing, playback, and lifecycle callbacks.

## Control motion

Pass a `MotionController` to control one or more `Motion` widgets from calling
code. The controller can be kept alongside other application state and shared
when several motions should respond to the same command.

The controller currently provides `play()` for starting a new motion run:

```dart
final motionController = MotionController();

Motion(
  controller: motionController,
  effect: const FadeInMotionEffect(),
  child: const Text('Saved'),
)

FilledButton(
  onPressed: motionController.play,
  child: const Text('Play again'),
)
```

`Motion` still plays when it first mounts. Calling `play()` returns every
attached motion to its initial visual state and starts a new run. Each effect
waits for its configured delay again. A call during playback interrupts the
current run, while a call after completion replays a one-shot effect.

Calling `play()` while no motions are attached does nothing.

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
`onEnd` while showing their finished visual state. Looping effects remain at
their initial visual state and do not start lifecycle callbacks while reduced
motion is enabled.

A disabled `TickerMode` mutes visual updates. A pending `onStart` waits until
the subtree is enabled; playback can then catch up to its elapsed position.
Looping effects do not complete while mounted and therefore never call
`onEnd`.

Set `playback: MotionPlayback.loop` on an effect that should repeat. Make its
progress `0` and `1` visuals equivalent so cycles remain seamless. Be careful
with a looping effect whose initial visual hides or displaces essential
content, because reduced motion intentionally keeps that initial visual.

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

One-shot effects run once automatically per mounted `Motion`; use a
`MotionController` to replay one. Looping effects should render equivalent
states at progress 0 and 1 so their cycles remain seamless.
