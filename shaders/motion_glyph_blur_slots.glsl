uniform float uBaseX;
uniform vec4 uParams[32];

struct Glyph {
  vec4 transform;
  vec4 bounds;
  vec4 weights;
  vec4 outerAndOpacity;
};

// SkSL requires constant indices into uniform arrays.
Glyph glyphAt(float slot) {
  if (slot < 4.0) {
    if (slot < 2.0) {
      if (slot < 1.0) {
        return Glyph(uParams[0], uParams[1], uParams[2], uParams[3]);
      }
      return Glyph(uParams[4], uParams[5], uParams[6], uParams[7]);
    }
    if (slot < 3.0) {
      return Glyph(uParams[8], uParams[9], uParams[10], uParams[11]);
    }
    return Glyph(uParams[12], uParams[13], uParams[14], uParams[15]);
  }
  if (slot < 6.0) {
    if (slot < 5.0) {
      return Glyph(uParams[16], uParams[17], uParams[18], uParams[19]);
    }
    return Glyph(uParams[20], uParams[21], uParams[22], uParams[23]);
  }
  if (slot < 7.0) {
    return Glyph(uParams[24], uParams[25], uParams[26], uParams[27]);
  }
  return Glyph(uParams[28], uParams[29], uParams[30], uParams[31]);
}
