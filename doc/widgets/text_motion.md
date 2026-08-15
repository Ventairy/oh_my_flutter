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
The default stagger is 30 milliseconds.

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

## Typography constraints

`TextMotion` is intended for short display text. Rendering graphemes
independently changes cross-character typography such as kerning, ligatures,
contextual shaping, line wrapping, bidirectional layout, and selection. It
accepts `Text('...')`; `Text.rich` is not supported.

Use ordinary `Text` or an editable text widget when exact paragraph shaping,
selection, or editing behavior matters more than per-grapheme motion.
