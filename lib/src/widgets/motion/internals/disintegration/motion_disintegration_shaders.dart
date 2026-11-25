part of '../../motion.dart';

abstract final class _MotionDisintegrationShaders {
  static const pointPadding = 2.0;

  static final Float64List motionParameters = Float64List.fromList([
    _MotionDisintegrationParameters.breakupRate,
    _MotionDisintegrationParameters.breakupShrink,
    _MotionDisintegrationParameters.lifetimeShrink,
    _MotionDisintegrationParameters.curlRotation,
    _MotionDisintegrationParameters.fadeStart,
    pointPadding,
  ]).asUnmodifiableView();

  static const vertex =
      '''
#version 300 es
precision highp float;
layout(location = 0) in vec4 aSource;
layout(location = 1) in vec4 aMotion;
layout(location = 2) in vec2 aCurl;
uniform vec2 uViewport;
uniform vec2 uOrigin;
uniform vec2 uScale;
uniform vec2 uImageSize;
uniform float uProgress;
uniform vec4 uPrefix;
uniform vec4 uSuffix;
uniform vec3 uDirection;
uniform vec2 uOpacity;
flat out vec4 vSource;
flat out vec2 vCenter;
flat out vec2 vSize;
flat out float vAlpha;
flat out float vRoundness;
flat out vec2 vRotation;
flat out vec4 vRestMapping;
void main() {
    float life = clamp((uProgress - aMotion.x) / aMotion.y, 0.0, 1.0);
    float unbroken = 1.0 - clamp(life * ${_MotionDisintegrationParameters.breakupRate}, 0.0, 1.0);
    float breakup = 1.0 - unbroken * unbroken * unbroken;
    float scale = (1.0 - ${_MotionDisintegrationParameters.breakupShrink} * breakup) * (1.0 - ${_MotionDisintegrationParameters.lifetimeShrink} * life);
    float angle = aCurl.x + life * ${_MotionDisintegrationParameters.curlRotation};
    float curl = sin(life * 3.141592653589793) * aCurl.y;
    vec2 pivot = uImageSize * 0.5;
    vec2 center = (aSource.xy + aSource.zw) * 0.5 - pivot;
    center = vec2(uPrefix.x * center.x - uPrefix.y * center.y,
                  uPrefix.y * center.x + uPrefix.x * center.y) + pivot + uPrefix.zw;
    vec2 drift = aMotion.zw * life + vec2(sin(angle), cos(angle)) * curl;
    center += vec2(uDirection.x * drift.x - uDirection.y * drift.y,
                   uDirection.y * drift.x + uDirection.x * drift.y) * uDirection.z;
    center -= pivot;
    center = vec2(uSuffix.x * center.x - uSuffix.y * center.y,
                  uSuffix.y * center.x + uSuffix.x * center.y) + pivot + uSuffix.zw;
    vec2 basis = vec2(uSuffix.x * uPrefix.x - uSuffix.y * uPrefix.y,
                      uSuffix.y * uPrefix.x + uSuffix.x * uPrefix.y);
    float magnitude = length(basis);
    vRotation = magnitude == 0.0 ? vec2(1.0, 0.0) : basis / magnitude;
    vRestMapping = vec4(0.0);
    if (life == 0.0 && magnitude > 0.0) {
        vec2 shift = vec2(uSuffix.x * uPrefix.z - uSuffix.y * uPrefix.w,
                          uSuffix.y * uPrefix.z + uSuffix.x * uPrefix.w);
        vRestMapping = vec4(pivot + shift + uSuffix.zw, basis / dot(basis, basis));
    }
    vec2 screen = uOrigin + center * uScale;
    vSource = aSource;
    vRoundness = breakup;
    vCenter = vec2(screen.x, uViewport.y - screen.y);
    vSize = (aSource.zw - aSource.xy) * scale * uScale * magnitude;
    float fade = clamp((life - ${_MotionDisintegrationParameters.fadeStart}) / ${1 - _MotionDisintegrationParameters.fadeStart}, 0.0, 1.0);
    vAlpha = floor((1.0 - fade * fade * (3.0 - 2.0 * fade)) * uOpacity.x * uOpacity.y * 255.0 + 0.5) / 255.0;
    gl_Position = vec4(screen.x / uViewport.x * 2.0 - 1.0, 1.0 - screen.y / uViewport.y * 2.0, 0.0, 1.0);
    // A padded point covers subpixel rectangles even when point coverage snaps to the pixel grid.
    gl_PointSize = ceil(max(dot(vSize, abs(vRotation)), dot(vSize.yx, abs(vRotation)))) + $pointPadding;
    if (uProgress >= 1.0 || vAlpha == 0.0) {
        gl_Position = vec4(2.0, 2.0, 0.0, 1.0);
        gl_PointSize = 1.0;
    }
}
''';

  static const fragment = '''
#version 300 es
precision highp float;
uniform sampler2D uImage;
uniform vec2 uImageSize;
uniform vec2 uViewport;
uniform vec2 uOrigin;
uniform vec2 uScale;
flat in vec4 vSource;
flat in vec2 vCenter;
flat in vec2 vSize;
flat in float vAlpha;
flat in float vRoundness;
flat in vec2 vRotation;
flat in vec4 vRestMapping;
out vec4 fragColor;
void main() {
    vec2 source;
    float coverage = 1.0;
    if (any(notEqual(vRestMapping.zw, vec2(0.0)))) {
        vec2 screen = vec2(gl_FragCoord.x, uViewport.y - gl_FragCoord.y);
        vec2 delta = (screen - uOrigin) / uScale - vRestMapping.xy;
        vec2 inverse = vRestMapping.zw;
        // Intact neighbors must agree on which side of their shared edge owns each pixel.
        source = vec2(inverse.x * delta.x + inverse.y * delta.y,
                     -inverse.y * delta.x + inverse.x * delta.y) + uImageSize * 0.5;
        if (any(lessThan(source, vSource.xy)) || any(greaterThanEqual(source, vSource.zw))) discard;
    } else {
        vec2 delta = vec2(gl_FragCoord.x - vCenter.x, vCenter.y - gl_FragCoord.y);
        delta = vec2(vRotation.x * delta.x + vRotation.y * delta.y,
                    -vRotation.y * delta.x + vRotation.x * delta.y);
        if (abs(delta.x) >= vSize.x * 0.5 || abs(delta.y) >= vSize.y * 0.5) discard;
        vec2 local = delta / vSize;
        float radiusSquared = 4.0 * dot(local, local);
        float feather = min(1.0, 2.0 / max(1.0, min(vSize.x, vSize.y)));
        coverage -= vRoundness * smoothstep(1.0 - feather, 1.0 + feather, radiusSquared);
        source = mix(vSource.xy, vSource.zw, local + 0.5);
    }
    fragColor = texture(uImage, source / uImageSize) * (vAlpha * coverage);
}
''';
}
