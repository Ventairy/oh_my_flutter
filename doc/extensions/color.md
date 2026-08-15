# Color transformations

Use `ColorExtension` for direct Flutter color transformations and hexadecimal
output.

```dart
final base = const Color(0xFFFF4A4B);

final lighter = base.lighten(0.12);
final darker = base.darken(0.12);
final hex = base.toHex();
```

`lighten` blends toward white and `darken` blends toward black. Their amounts
are clamped to the 0 to 1 interval. `toHex` returns lowercase `#RRGGBB` and does
not include alpha.

For perceptual color conversion and gamut handling, use the
[OKLCH guide](oklch.md).
