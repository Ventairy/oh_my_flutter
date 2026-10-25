/*
 * Copyright 2017 Google LLC
 * Derived from Skia src/core/SkMaskBlurFilter.cpp, PlanGauss.
 * Use of this source code is governed by a BSD-style license in SKIA_LICENSE.
 */
#pragma once
#include "skia_plan_gauss.h"
#include <array>
#include <cassert>
#include <vector>
#if defined(__ARM_NEON) && !defined(CONTOUR_FORCE_SCALAR_LANES)
#include <arm_neon.h>
#define CONTOUR_BLUR_HAS_NEON 1
#else
#define CONTOUR_BLUR_HAS_NEON 0
#endif

namespace contour_a8 { namespace internal {
namespace parallel_blur {
#if CONTOUR_BLUR_HAS_NEON
struct V8 { uint32x4_t lo, hi; };
inline V8 zero() { return {vdupq_n_u32(0),vdupq_n_u32(0)}; }
inline V8 add(V8 a,V8 b) { return {vaddq_u32(a.lo,b.lo),vaddq_u32(a.hi,b.hi)}; }
inline V8 sub(V8 a,V8 b) { return {vsubq_u32(a.lo,b.lo),vsubq_u32(a.hi,b.hi)}; }
inline V8 load_ring(const uint32_t* p) { return {vld1q_u32(p),vld1q_u32(p+4)}; }
inline void store_ring(uint32_t* p,V8 v) { vst1q_u32(p,v.lo);vst1q_u32(p+4,v.hi); }
inline V8 load_source(const uint8_t* p,int lanes) {
  uint8_t tail[8]{};
  if(lanes<8) {std::memcpy(tail,p,lanes);p=tail;}
  uint16x8_t v=vmovl_u8(vld1_u8(p));
  return {vmovl_u16(vget_low_u16(v)),vmovl_u16(vget_high_u16(v))};
}
inline uint32x4_t scale4(uint32x4_t v,uint32_t weight) {
  const uint32x2_t w=vdup_n_u32(weight);
  const uint64x2_t half=vdupq_n_u64(uint64_t(1)<<31);
  const uint64x2_t lo=vaddq_u64(vmull_u32(vget_low_u32(v),w),half);
  const uint64x2_t hi=vaddq_u64(vmull_u32(vget_high_u32(v),w),half);
  return vcombine_u32(vshrn_n_u64(lo,32),vshrn_n_u64(hi,32));
}
inline void store_scaled(uint8_t* p,V8 v,uint32_t weight,int lanes) {
  const uint16x8_t v16=vcombine_u16(vmovn_u32(scale4(v.lo,weight)),vmovn_u32(scale4(v.hi,weight)));
  const uint8x8_t v8=vmovn_u16(v16);
  if(lanes==8) {vst1_u8(p,v8);return;}
  uint8_t tail[8];vst1_u8(tail,v8);std::memcpy(p,tail,lanes);
}
#else
struct V8 { std::array<uint32_t,8> a{}; };
inline V8 zero() { return {}; }
inline V8 add(V8 a,V8 b) {for(int i=0;i<8;++i)a.a[i]+=b.a[i];return a;}
inline V8 sub(V8 a,V8 b) {for(int i=0;i<8;++i)a.a[i]-=b.a[i];return a;}
inline V8 load_ring(const uint32_t* p) {V8 v;std::memcpy(v.a.data(),p,32);return v;}
inline void store_ring(uint32_t* p,V8 v) {std::memcpy(p,v.a.data(),32);}
inline V8 load_source(const uint8_t* p,int lanes) {V8 v;for(int i=0;i<lanes;++i)v.a[i]=p[i];return v;}
inline void store_scaled(uint8_t* p,V8 v,uint32_t weight,int lanes) {
  for(int i=0;i<lanes;++i)p[i]=static_cast<uint8_t>((uint64_t(weight)*v.a[i]+(uint64_t(1)<<31))>>32);
}
#endif

inline void vertical8(const uint8_t* src,int height,int row_stride,
                      uint8_t* dst,int out_height,int lanes,
                      const PlanGauss& plan,uint32_t* ring) {
  const int n0=plan.fPass0Size,n1=plan.fPass1Size,n2=plan.fPass2Size;
  uint32_t* const b0=ring;
  uint32_t* const b1=ring+size_t(n0)*8;
  uint32_t* const b2=ring+size_t(n0+n1)*8;
  std::memset(ring,0,plan.bufferSize()*8*sizeof(uint32_t));
  V8 sum0=zero(),sum1=zero(),sum2=zero();
  int c0=0,c1=0,c2=0;
  const uint32_t weight=static_cast<uint32_t>(plan.fWeight);
  auto step=[&](V8 leading,uint8_t* out) __attribute__((always_inline)) {
    sum0=add(sum0,leading);sum1=add(sum1,sum0);sum2=add(sum2,sum1);
    store_scaled(out,sum2,weight,lanes);
    sum2=sub(sum2,load_ring(b2+size_t(c2)*8));store_ring(b2+size_t(c2)*8,sum1);
    if(++c2==n2)c2=0;
    sum1=sub(sum1,load_ring(b1+size_t(c1)*8));store_ring(b1+size_t(c1)*8,sum0);
    if(++c1==n1)c1=0;
    sum0=sub(sum0,load_ring(b0+size_t(c0)*8));store_ring(b0+size_t(c0)*8,leading);
    if(++c0==n0)c0=0;
  };
  int y=0;
  for(;y<height;++y)step(load_source(src+size_t(y)*row_stride,lanes),dst+size_t(y)*row_stride);
  const int no_change=std::max(0,plan.fSlidingWindow-height);
  for(int i=0;i<no_change;++i,++y)step(zero(),dst+size_t(y)*row_stride);
  std::memset(ring,0,plan.bufferSize()*8*sizeof(uint32_t));
  sum0=sum1=sum2=zero();c0=c1=c2=0;
  int sy=height;
  for(int dy=out_height-1;dy>=y;--dy)step(load_source(src+size_t(--sy)*row_stride,lanes),dst+size_t(dy)*row_stride);
}
} // namespace parallel_blur

// Preserve the scalar PlanGauss blur ordering and integer rounding. The
// horizontal pass writes contiguous A8 rows instead of a transposed temporary;
// the vertical pass advances eight columns together.
inline int blur_sigma_ge2(const uint8_t* src,int width,int height,size_t stride,
                          double sigma,std::vector<uint8_t>& temporary,
                          std::vector<uint8_t>& result,std::vector<uint32_t>& ring) {
  assert(src&&width>0&&height>0&&stride>=static_cast<size_t>(width));
  assert(sigma>=2.0&&sigma<=135.0);
  const PlanGauss plan(sigma);
  const int border=plan.border(),ow=width+2*border,oh=height+2*border;
  ring.resize(plan.bufferSize()*8);
  temporary.resize(size_t(ow)*height);result.resize(size_t(ow)*oh);
  auto scan=plan.makeBlurScan(width,ring.data());
  for(int y=0;y<height;++y) {
    auto* dst=temporary.data()+size_t(y)*ow;
    const auto* in=src+size_t(y)*stride;
    scan.blur(in,in+width,dst,1,dst+ow);
  }
  for(int x=0;x<ow;x+=8)parallel_blur::vertical8(temporary.data()+x,height,ow,
      result.data()+x,oh,std::min(8,ow-x),plan,ring.data());
  return border;
}
}} // namespace contour_a8::internal
