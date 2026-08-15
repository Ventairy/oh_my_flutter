# Marquee

Use `Marquee` to move an ordered strip continuously through a clipped viewport.
While motion is enabled, the widget repeats for as long as it is mounted. The
duration covers one complete cycle and defaults to one second.

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

At least two children are required. The default direction is
`MarqueeDirection.right`, spacing is zero, interaction is disabled, and
gapless repetition is enabled. Keep the children list unchanged after passing
it to the widget.

Horizontal marquees fill a bounded parent width by default and use their
tallest child for height. Vertical marquees fill a bounded parent height and
use their widest child. Supply `width` or `height` for a fixed viewport
dimension when the parent is unbounded along that axis.

## Choose the repetition layout

With `infinity: true`, the child sequence repeats as many times as needed to
keep the viewport filled without a gap between cycles. Set `infinity: false`
to keep one copy of each child; that single strip repeatedly travels from fully
outside the entry edge to fully outside the exit edge.

Do not use a `GlobalKey` anywhere inside a child while `infinity` is enabled,
because the same child can be visible more than once. Pointer interaction is
disabled by default; set `interactive: true` when moving children should accept
input. Reduced-motion preferences leave the strip visible in its initial
static arrangement, with repeated copies excluded from accessibility output.

`duration` must be positive. `spacing`, `width`, and `height` use logical pixels
and must be finite and non-negative.
