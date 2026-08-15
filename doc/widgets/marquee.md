# Marquee

Use `Marquee` to move an ordered strip continuously through a clipped viewport.
The duration covers one complete pass of the source strip.

## Basic usage

```dart
const Marquee(
  direction: MarqueeDirection.left,
  duration: Duration(seconds: 4),
  spacing: 24,
  infinity: true,
  children: [
    Text('Portable'),
    Text('Strongly typed'),
    Text('Low allocation'),
  ],
)
```

Horizontal marquees fill a bounded parent width by default and use their
tallest child for height. Vertical marquees fill a bounded parent height and
use their widest child. Supply `width` or `height` for a fixed viewport
dimension.

## Continuous and single-pass playback

With `infinity: true`, `Marquee` mounts the minimum cyclic child prefix needed
to keep the viewport filled without a gap between loops. Set `infinity: false`
to mount each child once and use an offscreen-to-offscreen pass.

Child subtrees containing `GlobalKey`s are not supported while infinity is
enabled. Pointer interaction is disabled by default; set `interactive: true`
when moving children should accept input. Reduced-motion preferences leave the
strip visible in a static arrangement.
