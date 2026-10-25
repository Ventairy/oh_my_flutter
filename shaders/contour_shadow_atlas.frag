#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uOrigin;
uniform vec2 uTileSize;
uniform vec2 uAtlasSize;
uniform float uIndex;
uniform float uFraction;
uniform float uColumns;
uniform float uMaximumIndex;
uniform float uCubic;
uniform sampler2D uAtlas;
out vec4 fragColor;
vec4 tileSample(float index,vec2 point){
  vec2 tile=vec2(mod(index,uColumns),floor(index/uColumns));
  vec2 pixel=clamp(point,vec2(.5),uTileSize-vec2(.5));
  return texture(uAtlas,(tile*uTileSize+pixel)/uAtlasSize);
}
vec4 harmonic(vec4 a,vec4 b){
  return step(vec4(1e-10),a*b)*(2.0*a*b)/(a+b+vec4(1e-12));
}
vec4 endpoint(vec4 d0,vec4 d1){
  vec4 m=(3.0*d0-d1)*.5;
  m*=step(vec4(1e-10),m*d0);
  return mix(m,3.0*d0,step(vec4(1e-10),-d0*d1)*step(3.0*abs(d0),abs(m)));
}
void main(){
  vec2 point=FlutterFragCoord().xy-uOrigin;
  if(uCubic<.5){
    fragColor=mix(tileSample(uIndex,point),tileSample(min(uIndex+1.0,uMaximumIndex),point),uFraction);
    return;
  }
  vec4 v0=tileSample(max(uIndex-1.0,0.0),point);
  vec4 v1=tileSample(uIndex,point);
  vec4 v2=tileSample(uIndex+1.0,point);
  vec4 v3=tileSample(min(uIndex+2.0,uMaximumIndex),point);
  vec4 d0=v1-v0,d1=v2-v1,d2=v3-v2;
  vec4 m1=uIndex<.5?endpoint(d1,d2):harmonic(d0,d1);
  vec4 m2=uIndex>uMaximumIndex-1.5?endpoint(d1,d0):harmonic(d1,d2);
  float t=uFraction,t2=t*t,t3=t2*t;
  fragColor=clamp((2.0*t3-3.0*t2+1.0)*v1+(t3-2.0*t2+t)*m1+(-2.0*t3+3.0*t2)*v2+(t3-t2)*m2,0.0,1.0);
  fragColor.rgb=min(fragColor.rgb,vec3(fragColor.a));
}
