#include <metal_stdlib>
using namespace metal;

struct DisintegrateVertex {
  float4 position [[position]];
  float pointSize [[point_size]];
  float4 source [[flat]];
  float2 center [[flat]];
  float2 size [[flat]];
  float alpha [[flat]];
  float roundness [[flat]];
  float2 rotation [[flat]];
  float4 restMapping [[flat]];
};

vertex DisintegrateVertex omf_disintegrate_vertex(
  uint vertexID [[vertex_id]],
  const device float* attributes [[buffer(0)]],
  constant float* uniforms [[buffer(1)]]
) {
  uint offset = vertexID * 10;
  float4 source = float4(attributes[offset], attributes[offset + 1], attributes[offset + 2], attributes[offset + 3]);
  float4 motion = float4(attributes[offset + 4], attributes[offset + 5], attributes[offset + 6], attributes[offset + 7]);
  float2 curlParameters = float2(attributes[offset + 8], attributes[offset + 9]);
  float2 imageSize = float2(uniforms[0], uniforms[1]);
  float2 viewport = float2(uniforms[2], uniforms[3]);
  float2 origin = float2(uniforms[4], uniforms[5]);
  float2 outputScale = float2(uniforms[6], uniforms[7]);
  float progress = uniforms[8];
  float4 prefix = float4(uniforms[9], uniforms[10], uniforms[11], uniforms[12]);
  float4 suffix = float4(uniforms[13], uniforms[14], uniforms[15], uniforms[16]);
  float2 opacity = float2(uniforms[17], uniforms[18]);
  float3 direction = float3(uniforms[19], uniforms[20], uniforms[21]);
  float life = clamp((progress - motion.x) / motion.y, 0.0f, 1.0f);
  float unbroken = 1.0f - clamp(life * uniforms[22], 0.0f, 1.0f);
  float breakup = 1.0f - unbroken * unbroken * unbroken;
  float scale = (1.0f - uniforms[23] * breakup) * (1.0f - uniforms[24] * life);
  float2 pivot = imageSize * 0.5f;
  float2 center = (source.xy + source.zw) * 0.5f - pivot;
  center = float2(prefix.x * center.x - prefix.y * center.y,
                  prefix.y * center.x + prefix.x * center.y) + pivot + prefix.zw;
  if (direction.z != 0.0f) {
    float angle = curlParameters.x + life * uniforms[25];
    float curl = sin(life * M_PI_F) * curlParameters.y;
    float2 drift = motion.zw * life + float2(sin(angle), cos(angle)) * curl;
    center += float2(direction.x * drift.x - direction.y * drift.y,
                      direction.y * drift.x + direction.x * drift.y) * direction.z;
  }
  center -= pivot;
  center = float2(suffix.x * center.x - suffix.y * center.y,
                  suffix.y * center.x + suffix.x * center.y) + pivot + suffix.zw;
  float2 basis = float2(suffix.x * prefix.x - suffix.y * prefix.y,
                        suffix.y * prefix.x + suffix.x * prefix.y);
  float magnitude = length(basis);
  DisintegrateVertex result;
  result.rotation = magnitude == 0.0f ? float2(1.0f, 0.0f) : basis / magnitude;
  result.restMapping = float4(0.0f);
  if (life == 0.0f && magnitude > 0.0f) {
    float2 shift = float2(suffix.x * prefix.z - suffix.y * prefix.w,
                         suffix.y * prefix.z + suffix.x * prefix.w);
    result.restMapping = float4(pivot + shift + suffix.zw, basis / dot(basis, basis));
  }
  float2 screen = origin + center * outputScale;
  result.source = source;
  result.roundness = breakup;
  result.center = screen;
  result.size = (source.zw - source.xy) * scale * outputScale * magnitude;
  float fade = clamp((life - uniforms[26]) / (1.0f - uniforms[26]), 0.0f, 1.0f);
  result.alpha = floor((1.0f - fade * fade * (3.0f - 2.0f * fade)) * opacity.x * opacity.y * 255.0f + 0.5f) / 255.0f;
  result.position = float4(screen.x / viewport.x * 2.0f - 1.0f, 1.0f - screen.y / viewport.y * 2.0f, 0.0f, 1.0f);
  result.pointSize = ceil(max(dot(result.size, abs(result.rotation)), dot(result.size.yx, abs(result.rotation)))) + uniforms[27];
  if (progress >= 1.0f || result.alpha == 0.0f) {
    result.position = float4(2.0f, 2.0f, 0.0f, 1.0f);
    result.pointSize = 1.0f;
  }
  return result;
}

fragment float4 omf_disintegrate_fragment(
  DisintegrateVertex particle [[stage_in]],
  texture2d<float> image [[texture(0)]],
  constant float* uniforms [[buffer(1)]]
) {
  float2 imageSize = float2(uniforms[0], uniforms[1]);
  float2 source;
  float coverage = 1.0f;
  if (any(particle.restMapping.zw != 0.0f)) {
    float2 origin = float2(uniforms[4], uniforms[5]);
    float2 outputScale = float2(uniforms[6], uniforms[7]);
    float2 delta = (particle.position.xy - origin) / outputScale - particle.restMapping.xy;
    float2 inverse = particle.restMapping.zw;
    // Intact neighbors must agree on which side of their shared edge owns each pixel.
    source = float2(inverse.x * delta.x + inverse.y * delta.y,
                    -inverse.y * delta.x + inverse.x * delta.y) + imageSize * 0.5f;
    if (any(source < particle.source.xy) || any(source >= particle.source.zw)) discard_fragment();
  } else {
    float2 delta = particle.position.xy - particle.center;
    delta = float2(particle.rotation.x * delta.x + particle.rotation.y * delta.y,
                   -particle.rotation.y * delta.x + particle.rotation.x * delta.y);
    if (abs(delta.x) >= particle.size.x * 0.5f || abs(delta.y) >= particle.size.y * 0.5f) discard_fragment();
    float2 local = delta / particle.size;
    float radiusSquared = 4.0f * dot(local, local);
    float feather = min(1.0f, 2.0f / max(1.0f, min(particle.size.x, particle.size.y)));
    coverage -= particle.roundness * smoothstep(1.0f - feather, 1.0f + feather, radiusSquared);
    source = mix(particle.source.xy, particle.source.zw, local + 0.5f);
  }
  constexpr sampler sourceSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
  return image.sample(sourceSampler, source / imageSize) * (particle.alpha * coverage);
}

struct DisintegrateGaussianUniforms {
  float2 step;
  float center;
  uint count;
};

vertex float4 omf_disintegrate_gaussian_vertex(uint vertexID [[vertex_id]]) {
  return float4(vertexID == 1 ? 3.0f : -1.0f, vertexID == 2 ? 3.0f : -1.0f, 0.0f, 1.0f);
}

fragment float4 omf_disintegrate_gaussian_fragment(
  float4 position [[position]],
  constant DisintegrateGaussianUniforms& uniforms [[buffer(0)]],
  constant float2* taps [[buffer(1)]],
  texture2d<float> image [[texture(0)]]
) {
  constexpr sampler imageSampler(coord::normalized, address::clamp_to_zero, filter::linear);
  float2 uv = position.xy / float2(image.get_width(), image.get_height());
  float4 color = image.sample(imageSampler, uv) * uniforms.center;
  for (uint index = 0; index < uniforms.count; ++index) {
    float2 delta = uniforms.step * taps[index].x;
    color += (image.sample(imageSampler, uv + delta) + image.sample(imageSampler, uv - delta)) * taps[index].y;
  }
  return color;
}
