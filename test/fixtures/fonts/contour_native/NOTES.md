These two small fonts are self-authored CC0 diagnostic fixtures. They contain no
third-party outlines or artwork. Run `python3 build_font.py` with FontTools
installed to regenerate them.

- `contour_vector.ttf` maps `A` to a simple filled shape with a curved top.
- `contour_mixed_bitmap.ttf` maps `x` to an analytically drawn white PNG ring in
  an OpenType `sbix` strike. Its zero-area outline points establish bitmap bounds
  without supplying a visible vector outline.

The bitmap glyph remains visible but ignores a foreground stroke on Skia. The
regression combines many large vector glyphs with one small bitmap ring in a
single paragraph. Paragraph-wide checks can hide the ring's unsupported stroke
inside an allowance dominated by the larger vector glyphs; component checks must
reject it so the captured contour remains in use.

The separate vector font avoids platform-specific assumptions about outline
fallback for glyphs that lack an `sbix` record.
