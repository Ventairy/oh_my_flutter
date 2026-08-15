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

`Oklch` stores lightness from `0` to `1`, chroma as a non-negative intensity,
and hue in degrees from `0` up to but not including `360`. Chroma is commonly
within roughly `0` to `0.37` for sRGB, but wider-gamut colors can exceed that
range. Conversion ignores alpha and produces an opaque color.

Output defaults to `ColorSpace.sRGB`. `ColorSpace.extendedSRGB` and
`ColorSpace.displayP3` are also supported:

```dart
final p3 = adjusted.toColor(colorSpace: ColorSpace.displayP3);
```

When converting to a color, lightness is clamped to `0...1`, negative chroma
becomes zero, and hue wraps into `0...360`. Colors outside bounded sRGB or
Display P3 are gamut-mapped while preserving lightness and hue as closely as
possible. Extended sRGB does not apply bounded RGB gamut mapping. Non-finite
components throw `ArgumentError` when `toColor` is called; the `Oklch`
constructor itself stores the supplied values. Achromatic colors use zero
degrees for hue.
