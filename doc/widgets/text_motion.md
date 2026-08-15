# TextMotion

Use `TextMotion` to apply `MotionEffect`s to every visible Unicode grapheme in
a plain Flutter `Text`.

## Basic usage

```dart
const TextMotion(
  effect: MoveMotionEffect(
    begin: Offset(0, 8),
    end: Offset.zero,
  ),
  stagger: Duration(milliseconds: 30),
  child: Text('Welcome'),
)
```

Whitespace and invisible formatting controls remain static paragraph spans.
The default stagger is 30 milliseconds and cannot be negative. Effect timing,
curves, playback, controller behavior, lifecycle callbacks, interaction,
reduced motion, and `TickerMode` follow [Motion](motion.md).

## Combine effects

```dart
const TextMotion.list(
  effects: [
    FadeInMotionEffect(),
    ScaleInMotionEffect(scale: 0.8),
  ],
  stagger: Duration(milliseconds: 30),
  child: Text('Ready'),
)
```

One-shot effects finish after the last grapheme completes. Looping effects keep
their configured cycle duration and use the stagger as a phase offset. Each
effect has one shared lifecycle, so `onStart` and `onEnd` fire once for the
complete text rather than once per grapheme. Reduced motion, `TickerMode`,
interaction, delays, and playback otherwise match `Motion`.

## Choose startup behavior

Use the same `MotionStartup` values as `Motion` to play text automatically,
hold every visible grapheme at its effect's starting state, or skip every
grapheme to its ending state:

```dart
TextMotion(
  startup: MotionStartup.skip,
  controller: motionController,
  effect: const FadeInMotionEffect(),
  child: const Text('Welcome'),
)
```

Held and skipped text does not schedule playback or call effect lifecycle
callbacks. Startup applies only when `TextMotion` mounts; use a new key to
apply another startup behavior. Calling `MotionController.play()` later starts
the complete text timeline from the beginning with its configured delays and
stagger.

## Control text motion

Pass a `MotionController` when calling code needs to control a `TextMotion`.
The same controller can be shared with other `TextMotion` and `Motion` widgets
when they should respond to the same command.

The controller currently provides `play()` for starting a new motion run:

```dart
final motionController = MotionController();

TextMotion(
  controller: motionController,
  startup: MotionStartup.skip,
  effect: const FadeInMotionEffect(),
  stagger: const Duration(milliseconds: 30),
  child: const Text('Welcome'),
)

FilledButton(
  onPressed: motionController.play,
  child: const Text('Play again'),
)
```

Calling `play()` returns every visible grapheme to its initial visual state and
starts the complete text timeline, regardless of its startup behavior. Each
effect waits for its configured delay, and neighboring graphemes use the
configured stagger again. A call during playback interrupts the current run; a
call after completion replays the text.

Text with no visible graphemes schedules no motion, so calling `play()` has no
observable effect for that `TextMotion`.

## Typography constraints

`TextMotion` is intended for short display text. Rendering graphemes
independently changes cross-character typography such as kerning, ligatures,
contextual shaping, line wrapping, bidirectional layout, and selection. It
accepts `Text('...')`; `Text.rich` is not supported.

Use ordinary `Text` or an editable text widget when exact paragraph shaping,
selection, or editing behavior matters more than per-grapheme motion.
