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
rotate, shake, continuously float, or pulse a widget's opacity. Unless a constructor
documents another value, effects start immediately, last 300 milliseconds, use
`Curves.linear`, and run once:

```dart
const Motion(
  effect: FadeInMotionEffect(),
  child: Text('Ready'),
)

const Motion(
  effect: PulseFadeMotionEffect(minOpacity: 0.4),
  child: Icon(Icons.favorite),
)

const Motion(
  effect: ScaleInMotionEffect(scale: 0.6),
  child: Icon(Icons.check),
)

const Motion(
  effect: ScaleOutMotionEffect(scale: 0.6),
  child: Icon(Icons.close),
)

const Motion(
  effect: MoveMotionEffect(
    begin: Offset(-24, 0),
    end: Offset.zero,
  ),
  child: Icon(Icons.arrow_forward),
)

const Motion(
  effect: RotateMotionEffect(degrees: 90),
  child: Icon(Icons.refresh),
)

const Motion(
  effect: ShakeMotionEffect(
    offset: Offset(6, 0),
    count: 3,
    damping: 1,
    duration: Duration(milliseconds: 1300),
    curve: Curves.easeOutBack,
  ),
  child: Icon(Icons.warning_amber),
)
```

`ScaleInMotionEffect.scale` is the starting size before the child reaches its
normal size. `ScaleOutMotionEffect.scale` is the ending size after the child
leaves its normal size. Both effects preserve the child's layout dimensions.

`RotateMotionEffect.degrees` is the angle relative to the child's starting
orientation. Positive values turn clockwise on screen; negative values turn
counterclockwise. The child rotates around its center without changing layout.
Set `degrees: 360` for a full turn.

`PulseFadeMotionEffect` repeatedly dims from full opacity to `minOpacity` and
back over each cycle. The default minimum is `0.5`, and one cycle lasts two
seconds. Set `minOpacity` to zero to fade out completely or to one to remain
fully visible. With reduced motion enabled, the child stays fully visible.

`ShakeMotionEffect.offset` sets both direction and strength. Use a horizontal,
vertical, or diagonal offset, and reverse its coordinates to reverse the first
excursion. `count` controls how many alternating excursions occur. Set
`damping` to zero to retain the requested strength or one to taper it linearly
toward rest.

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

## Choose startup behavior

Motion plays automatically when it first mounts. Set `startup` to display a
static effect state instead:

```dart
Motion(
  startup: MotionStartup.skip,
  controller: motionController,
  effect: const FadeInMotionEffect(),
  child: const Text('Saved'),
)
```

`MotionStartup.play` keeps automatic playback. `MotionStartup.hold` displays
every effect at progress `0`, while `MotionStartup.skip` displays every effect
at progress `1`. Held and skipped effects do not wait, play, or call lifecycle
callbacks, and they remain interactive with the default `interactive` value.

Startup behavior applies only when the widget mounts. Rebuilding with another
`startup` value does not change the visible state; give the widget a new key to
apply different startup behavior. A later `MotionController.play()` call
starts held or skipped motion normally from progress `0`, including each
effect's configured delay.

For `Motion.list`, startup applies the same progress endpoint to every effect.
A looping effect should already render equivalent states at progress `0` and
`1`, so holding or skipping it produces the same resting appearance.

## Control motion

Pass a `MotionController` to control one or more motion widgets from calling
code. The controller can be kept alongside other application state and shared
with `Motion` and `TextMotion` widgets when several motions should respond to
the same command.

The controller currently provides `play()` for starting a new motion run:

```dart
final motionController = MotionController();

Motion(
  controller: motionController,
  startup: MotionStartup.skip,
  effect: const FadeInMotionEffect(),
  child: const Text('Saved'),
)

FilledButton(
  onPressed: motionController.play,
  child: const Text('Play again'),
)
```

Calling `play()` returns every attached motion to its initial visual state and
starts a new run, regardless of its startup behavior. Each effect waits for its
configured delay again. A call during playback interrupts the current run,
while a call after completion replays a one-shot effect.

Calling `play()` while no motion widgets are attached does nothing.

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
effect otherwise keeps interaction disabled while playing. Held and skipped
startup states are idle and do not block interaction.

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

One-shot effects use the enclosing Motion's startup behavior; use a
`MotionController` to play one on demand or replay one. Looping effects should
render equivalent states at progress 0 and 1 so their cycles remain seamless.

`apply` is called during both effect setup and visible playback. Keep it
deterministic, synchronous, and free of side effects. `MotionEffectTransform`
supports opacity, translation, uniform scale, rotation in degrees, and blur.

### Bring content into focus

Use `transform.blur(sigma)` to soften the content as it enters or leaves.
Sigma is measured in logical pixels. Start with a small value such as `3`
and end at `0` to bring the content into focus. A fade can make the same
reveal feel gentler. In `TextMotion`, set `stagger` to bring neighboring
characters into focus in sequence.

For design references, see [Emil Kowalski’s Linear intro](https://x.com/emilkowalski/status/1987892934587412676)
and [Rauno Freiberg’s motion choreography](https://x.com/raunofreiberg/status/1965344575507365926).

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';

class FocusReveal extends MotionEffect {
  const FocusReveal() : super(duration: const Duration(milliseconds: 240));

  @override
  void apply(double progress, MotionEffectTransform transform) {
    final t = progress.clamp(0.0, 1.0);
    transform
      ..fade(t)
      ..blur(3 * (1 - t));
  }
}
```

Each call acts on the visual state produced by the calls before it. For
example, a scale after blur also scales the softened edges. With a delayed
effect, start at sigma `0` to keep the content sharp until that effect plays.

```dart
import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class SoftDisintegration extends MotionEffect {
  const SoftDisintegration() : super(duration: const Duration(milliseconds: 360));

  @override
  void apply(double progress, MotionEffectTransform transform) {
    final t = progress.clamp(0.0, 1.0);
    transform
      ..disintegrate(progress: t, direction: const Offset(1, -0.5))
      ..blur(12 * t * (1 - t));
  }
}
```

### Declare bounds for brief or abrupt transformations

Built-in effects and custom effects whose complete curved path is monotonic,
such as the slide above with a non-overshooting curve, can leave `bounds` null.
Account for the configured curve as part of that path: a monotonic formula may
stop being monotonic when its curve overshoots or oscillates.

An oscillating, abrupt, or short-lived custom effect must declare conservative
bounds when its translation, growth, rotation, or blur can briefly extend
beyond the reserved paint area. Use `maximumBlurSigma` to reserve room
for a brief blur peak. If the exact range is difficult to calculate, give it
extra room. The bounds reserve paint area for the effect.

During setup, when Motion mounts or receives different effects, it evaluates
65 evenly spaced timeline positions from `0` through `1`. Each position passes
through the configured curve before Motion calls `apply`. These calls are the
bounds samples: Motion uses their transformations to estimate the paint area
the effect needs. They are unrelated to animation FPS, do not replace the
normal `apply` calls made during visible playback, and are not repeated when a
controller replays the same effects.

A short-lived extreme can occur between two samples. The animation can still
reach and paint that transformation, but its estimated visual space may be too
small and clip the extreme. Checking more progress values would reduce the gap
without guaranteeing that every possible peak is found, while also increasing
effect setup work. The sample count is therefore not configurable; declare
conservative `bounds` whenever the effect's complete range may not be
represented by the 65 samples.

```dart
import 'dart:math' as math;

class JitterMotionEffect extends MotionEffect {
  const JitterMotionEffect({required this.offset});

  final Offset offset;

  @override
  MotionEffectBounds get bounds {
    final extent = Offset(offset.dx.abs(), offset.dy.abs());
    return MotionEffectBounds(
      minimumOffset: -extent,
      maximumOffset: extent,
    );
  }

  @override
  void apply(double progress, MotionEffectTransform transform) {
    final displacement = math.sin(progress * math.pi * 12);
    transform.translate(
      x: offset.dx * displacement,
      y: offset.dy * displacement,
    );
  }
}
```

For a brief scale pulse that may grow to `1.4`, declare a scale-only bound:

```dart
@override
MotionEffectBounds get bounds =>
    const MotionEffectBounds(maximumScale: 1.4);
```

The offset fields default to zero and `maximumScale` defaults to one.
`maximumScale` is the largest absolute uniform scale the effect can reach;
values below one require no additional paint area. Motion may keep more area
available when it finds a larger translation, scale, or configured curve
overshoot than the declared range.

For a brief rotation that samples may miss, declare its largest absolute angle:

```dart
@override
MotionEffectBounds get bounds =>
    const MotionEffectBounds(maximumRotationDegrees: 90);
```

`maximumRotationDegrees` reserves room for the child to turn around its center.

## Disintegrate content

`DisintegrateMotionEffect` breaks a widget into small pieces that shrink and
fade away. Direction controls travel rather than speed. Nonzero vectors are
normalized; `Offset.zero` keeps every piece in place, including its random
movement. The default desired piece size is 2.2 logical source pixels. Large
widgets may use larger pieces to keep the effect affordable.

```dart
Motion(
  effect: const DisintegrateMotionEffect(
    direction: Offset(0, -1),
    duration: Duration(seconds: 2),
  ),
  child: const Text('See you around'),
)
```

The child is captured once when playback is requested. Its appearance stays
frozen for that run. Preparation finishes before playback and `onStart` begin;
the configured duration does not include preparation. Calling `play()` again
captures the current child and replaces the previous run. With looping playback,
the same captured content is reused until replay.

### Compose a custom effect

Use `disintegrate` inside the same `apply` method as the other operations:

```dart
class ShrinkingDisintegrateMotionEffect extends MotionEffect {
  const ShrinkingDisintegrateMotionEffect({
    super.duration = const Duration(seconds: 2),
    super.onEnd,
  });

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.disintegrate(
      progress: progress,
      direction: const Offset(0, -1),
    );
    transform.scale(1 - 0.2 * progress);
  }
}
```

Operations apply in declaration order. Scaling after disintegration scales the
pieces and their displacement together. Scaling before it changes the input
before the pieces move. If blur comes before disintegration, the pieces keep the
blur they had when breakup began. Blur applied after disintegration can keep
changing as the pieces move. Multiple disintegration calls compose in order too.

Keep the number/order of `disintegrate` calls and each call's `particleSize`
constant throughout playback. To delay breakup, pass an interval-transformed
progress instead of conditionally calling the method. Progress outside zero
through one is clamped. Particle patterns are repeatable without a seed setting.

### Keep changing content underneath

The default `renderPresentation: MotionRenderPresentation.replace` displays
captured motion instead of the live child. Use `.overlay` when the child should
change underneath, such as removing an item from a feed while its old pixels
continue disappearing above the next item. Make that update in `onStart`, when
the captured output is ready, and set `interactive: true` to keep the live child
interactive during the animation. The overlay does not accept pointer input.

Captured effects need paintable Flutter content. Native platform views are not
guaranteed to appear in captures. If preparation is unavailable, motion skips the
visual treatment while preserving lifecycle callbacks. The same primitive works
in `TextMotion`, with its existing typography and per-character timing rules.
