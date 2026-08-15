# OKLCH colors

Use `Oklch` when color work should use perceptually uniform lightness, chroma,
and hue instead of RGB channels.

## Convert between Color and OKLCH

```dart
final color = const Color(0xFFFF4A4B);
final oklch = color.toOklch();

final adjusted = Oklch(
  oklch.l + 0.08,
  oklch.c,
  oklch.h,
);

final restored = adjusted.toColor();
```

`Oklch` stores lightness, chroma, and hue as immutable values. Conversion
ignores alpha. Output defaults to sRGB; pass a supported `ColorSpace` to
`toColor` when another output space is required.

Colors outside bounded sRGB or Display P3 are gamut-mapped while preserving
lightness and hue as closely as possible. Non-finite components are rejected.
See the [API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/Oklch-class.html)
for normalization and color-space details.
