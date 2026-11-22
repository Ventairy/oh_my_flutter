uniform vec2 uImageSize;
#ifdef MOTION_GLYPH_BLUR_MESH
#include "motion_glyph_blur_slots.glsl"
#else
uniform vec2 uOrigin;
uniform vec2 uInverse;
uniform vec4 uSprite;
uniform float uCenterWeight;
uniform vec4 uSideWeights;
uniform float uOpacity;
#endif
uniform sampler2D uImage;
out vec4 fragColor;

struct Tap {
  vec2 distance;
  vec2 weight;
};

Tap pairTap(float left, vec2 a, vec2 b) {
  vec2 sum = a + b;
  return Tap(left + b / max(sum, vec2(1e-15)), sum);
}

Tap constrainTap(Tap tap, vec2 texel, vec4 sprite) {
  // Apply transparent-edge clipping on each axis before combining samples.
  vec2 point = texel + tap.distance;
  tap.weight *= step(sprite.xy, point) * step(point, sprite.zw);
  tap.distance = clamp(point, sprite.xy + .5, sprite.zw - .5) / uImageSize;
  return tap;
}

#ifndef MOTION_GLYPH_BLUR_ROW_LOOP
vec4 row(float y, Tap left, Tap center, Tap right) {
  return texture(uImage, vec2(left.distance.x, y)) * left.weight.x
      + texture(uImage, vec2(center.distance.x, y)) * center.weight.x
      + texture(uImage, vec2(right.distance.x, y)) * right.weight.x;
}

vec4 wideRow(Tap vertical, Tap farLeft, Tap left, Tap center, Tap right, Tap farRight) {
  // All five samples contribute zero when this row is outside the sprite.
  if (vertical.weight.y == 0.0) return vec4(0.0);
  float y = vertical.distance.y;
  return (row(y, left, center, right)
      + texture(uImage, vec2(farLeft.distance.x, y)) * farLeft.weight.x
      + texture(uImage, vec2(farRight.distance.x, y)) * farRight.weight.x) * vertical.weight.y;
}
#endif

void main() {
#ifdef MOTION_GLYPH_BLUR_MESH
  vec2 encodedPoint = FlutterFragCoord().xy;
  float slot = floor(encodedPoint.x / 2048.0);
  Glyph glyph = glyphAt(slot);
  vec2 position = vec2((encodedPoint.x - (slot * 2048.0 + 512.0)) + uBaseX, encodedPoint.y);
  vec2 coords = position - glyph.transform.xy;
  vec2 inverse = glyph.transform.zw;
  vec4 sprite = glyph.bounds;
  float w0 = glyph.weights.x;
  float w1 = glyph.weights.y;
  float w2 = glyph.weights.z;
  float w3 = glyph.weights.w;
  float w4 = glyph.outerAndOpacity.x;
  float opacity = glyph.outerAndOpacity.y;
#else
  vec2 coords = FlutterFragCoord().xy - uOrigin;
  vec2 inverse = uInverse;
  vec4 sprite = uSprite;
  float w0 = uCenterWeight;
  float w1 = uSideWeights.x;
  float w2 = uSideWeights.y;
  float w3 = uSideWeights.z;
  float w4 = uSideWeights.w;
  float opacity = uOpacity;
#endif
  vec2 point = sprite.xy + vec2(dot(coords, inverse), dot(coords, vec2(-inverse.y, inverse.x)));
  vec2 texel = floor(point - .5) + .5;
  vec2 t = point - texel;
  vec2 s = 1.0 - t;
  // In one axis each pair lands between its two source texels.
  bool wide = w4 != 0.0;
  vec2 earliest = texel + (wide ? -4.0 : -2.0);
  vec2 latest = texel + (wide ? 5.0 : 3.0);
  bvec2 beforeSprite = lessThan(latest, sprite.xy);
  bvec2 afterSprite = greaterThan(earliest, sprite.zw);
  // Strict comparisons preserve taps on the inclusive sprite edges.
  // Qualify the discarded axis in case rounding moved t off [0, 1].
  if (((beforeSprite.x || afterSprite.x) && t.x >= 0.0 && t.x <= 1.0)
      || ((beforeSprite.y || afterSprite.y) && t.y >= 0.0 && t.y <= 1.0)) {
    fragColor = vec4(0.0);
  } else {
    // Interpolate two translated discrete kernels before pairing adjacent taps.
    // This keeps each kernel centered correctly between source texels.
#ifdef MOTION_GLYPH_BLUR_ROW_LOOP
    // Keeping the horizontal taps unrolled preserves throughput on Android Skia.
    Tap taps[5];
    taps[0] = constrainTap(pairTap(-2.0, s*w2 + t*w3, s*w1 + t*w2), texel, sprite);
    taps[1] = constrainTap(pairTap(0.0, s*w0 + t*w1, s*w1 + t*w0), texel, sprite);
    taps[2] = constrainTap(pairTap(2.0, s*w2 + t*w1, s*w3 + t*w2), texel, sprite);
    taps[3] = constrainTap(pairTap(-4.0, s*w4, s*w3 + t*w4), texel, sprite);
    taps[4] = constrainTap(pairTap(4.0, s*w4 + t*w3, t*w4), texel, sprite);

    int count = w4 == 0.0 ? 3 : 5;
    vec4 sum = vec4(0);
    for (int y = 0; y < 5; y++) {
      if (y == count) break;
      Tap vertical = taps[y];
      if (vertical.weight.y == 0.0) continue;
      float coordY = vertical.distance.y;
      vec4 rowSum = texture(uImage, vec2(taps[0].distance.x, coordY)) * taps[0].weight.x
          + texture(uImage, vec2(taps[1].distance.x, coordY)) * taps[1].weight.x
          + texture(uImage, vec2(taps[2].distance.x, coordY)) * taps[2].weight.x;
      if (wide) {
        rowSum += texture(uImage, vec2(taps[3].distance.x, coordY)) * taps[3].weight.x;
        rowSum += texture(uImage, vec2(taps[4].distance.x, coordY)) * taps[4].weight.x;
      }
      sum += rowSum * vertical.weight.y;
    }
#else
    Tap left = constrainTap(pairTap(-2.0, s*w2 + t*w3, s*w1 + t*w2), texel, sprite);
    Tap center = constrainTap(pairTap(0.0, s*w0 + t*w1, s*w1 + t*w0), texel, sprite);
    Tap right = constrainTap(pairTap(2.0, s*w2 + t*w1, s*w3 + t*w2), texel, sprite);
    vec4 sum;
    if (w4 == 0.0) {
      sum = row(left.distance.y, left,center,right)*left.weight.y
          + row(center.distance.y, left,center,right)*center.weight.y
          + row(right.distance.y, left,center,right)*right.weight.y;
    } else {
      Tap farLeft = constrainTap(pairTap(-4.0, s*w4, s*w3 + t*w4), texel, sprite);
      Tap farRight = constrainTap(pairTap(4.0, s*w4 + t*w3, t*w4), texel, sprite);
      sum = wideRow(farLeft, farLeft,left,center,right,farRight)
          + wideRow(left, farLeft,left,center,right,farRight)
          + wideRow(center, farLeft,left,center,right,farRight)
          + wideRow(right, farLeft,left,center,right,farRight)
          + wideRow(farRight, farLeft,left,center,right,farRight);
    }
#endif
    fragColor = sum * opacity;
  }
}
