/*
 * Copyright 2017 Google LLC
 * Derived from Skia src/core/SkMaskBlurFilter.cpp, PlanGauss.
 * Use of this source code is governed by a BSD-style license in SKIA_LICENSE.
 */
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
namespace contour_a8 { namespace internal {
class PlanGauss final {
public:
    explicit PlanGauss(double sigma) {
        auto possibleWindow = static_cast<int>(floor(sigma * 3 * sqrt(2 * 3.14159265358979323846264338327950288) / 4 + 0.5));
        auto window = std::max(1, possibleWindow);

        fPass0Size = window - 1;
        fPass1Size = window - 1;
        fPass2Size = (window & 1) == 1 ? window - 1 : window;

        // Calculating the border is tricky. I will go through the odd case which is simpler, and
        // then through the even case. Given a stack of filters seven wide for the odd case of
        // three passes.
        //
        //        S
        //     aaaAaaa
        //     bbbBbbb
        //     cccCccc
        //        D
        //
        // The furthest changed pixel is when the filters are in the following configuration.
        //
        //                 S
        //           aaaAaaa
        //        bbbBbbb
        //     cccCccc
        //        D
        //
        //  The A pixel is calculated using the value S, the B uses A, and the C uses B, and
        // finally D is C. So, with a window size of seven the border is nine. In general, the
        // border is 3*((window - 1)/2).
        //
        // For even cases the filter stack is more complicated. The spec specifies two passes
        // of even filters and a final pass of odd filters. A stack for a width of six looks like
        // this.
        //
        //       S
        //    aaaAaa
        //     bbBbbb
        //    cccCccc
        //       D
        //
        // The furthest pixel looks like this.
        //
        //               S
        //          aaaAaa
        //        bbBbbb
        //    cccCccc
        //       D
        //
        // For a window of size, the border value is seven. In general the border is 3 *
        // (window/2) -1.
        fBorder = (window & 1) == 1 ? 3 * ((window - 1) / 2) : 3 * (window / 2) - 1;
        fSlidingWindow = 2 * fBorder + 1;

        // If the window is odd then the divisor is just window ^ 3 otherwise,
        // it is window * window * (window + 1) = window ^ 2 + window ^ 3;
        auto window2 = window * window;
        auto window3 = window2 * window;
        auto divisor = (window & 1) == 1 ? window3 : window3 + window2;

        fWeight = static_cast<uint64_t>(round(1.0 / divisor * (1ull << 32)));
    }

    size_t bufferSize() const { return fPass0Size + fPass1Size + fPass2Size; }

    int    border()     const { return fBorder; }

public:
    class Scan {
    public:
        Scan(uint64_t weight, int noChangeCount,
             uint32_t* buffer0, uint32_t* buffer0End,
             uint32_t* buffer1, uint32_t* buffer1End,
             uint32_t* buffer2, uint32_t* buffer2End)
            : fWeight{weight}
            , fNoChangeCount{noChangeCount}
            , fBuffer0{buffer0}
            , fBuffer0End{buffer0End}
            , fBuffer1{buffer1}
            , fBuffer1End{buffer1End}
            , fBuffer2{buffer2}
            , fBuffer2End{buffer2End}
        { }

        template <typename AlphaIter> void blur(const AlphaIter srcBegin, const AlphaIter srcEnd,
                    uint8_t* dst, int dstStride, uint8_t* dstEnd) const {
            auto buffer0Cursor = fBuffer0;
            auto buffer1Cursor = fBuffer1;
            auto buffer2Cursor = fBuffer2;

            std::memset(fBuffer0, 0x00, (fBuffer2End - fBuffer0) * sizeof(*fBuffer0));

            uint32_t sum0 = 0;
            uint32_t sum1 = 0;
            uint32_t sum2 = 0;

            // Consume the source generating pixels.
            for (AlphaIter src = srcBegin; src < srcEnd; ++src, dst += dstStride) {
                uint32_t leadingEdge = *src;
                sum0 += leadingEdge;
                sum1 += sum0;
                sum2 += sum1;

                *dst = this->finalScale(sum2);

                sum2 -= *buffer2Cursor;
                *buffer2Cursor = sum1;
                buffer2Cursor = (buffer2Cursor + 1) < fBuffer2End ? buffer2Cursor + 1 : fBuffer2;

                sum1 -= *buffer1Cursor;
                *buffer1Cursor = sum0;
                buffer1Cursor = (buffer1Cursor + 1) < fBuffer1End ? buffer1Cursor + 1 : fBuffer1;

                sum0 -= *buffer0Cursor;
                *buffer0Cursor = leadingEdge;
                buffer0Cursor = (buffer0Cursor + 1) < fBuffer0End ? buffer0Cursor + 1 : fBuffer0;
            }

            // The leading edge is off the right side of the mask.
            for (int i = 0; i < fNoChangeCount; i++) {
                uint32_t leadingEdge = 0;
                sum0 += leadingEdge;
                sum1 += sum0;
                sum2 += sum1;

                *dst = this->finalScale(sum2);

                sum2 -= *buffer2Cursor;
                *buffer2Cursor = sum1;
                buffer2Cursor = (buffer2Cursor + 1) < fBuffer2End ? buffer2Cursor + 1 : fBuffer2;

                sum1 -= *buffer1Cursor;
                *buffer1Cursor = sum0;
                buffer1Cursor = (buffer1Cursor + 1) < fBuffer1End ? buffer1Cursor + 1 : fBuffer1;

                sum0 -= *buffer0Cursor;
                *buffer0Cursor = leadingEdge;
                buffer0Cursor = (buffer0Cursor + 1) < fBuffer0End ? buffer0Cursor + 1 : fBuffer0;

                dst += dstStride;
            }

            // Starting from the right, fill in the rest of the buffer.
            std::memset(fBuffer0, 0, (fBuffer2End - fBuffer0) * sizeof(*fBuffer0));

            sum0 = sum1 = sum2 = 0;

            uint8_t* dstCursor = dstEnd;
            AlphaIter src = srcEnd;
            while (dstCursor > dst) {
                dstCursor -= dstStride;
                uint32_t leadingEdge = *(--src);
                sum0 += leadingEdge;
                sum1 += sum0;
                sum2 += sum1;

                *dstCursor = this->finalScale(sum2);

                sum2 -= *buffer2Cursor;
                *buffer2Cursor = sum1;
                buffer2Cursor = (buffer2Cursor + 1) < fBuffer2End ? buffer2Cursor + 1 : fBuffer2;

                sum1 -= *buffer1Cursor;
                *buffer1Cursor = sum0;
                buffer1Cursor = (buffer1Cursor + 1) < fBuffer1End ? buffer1Cursor + 1 : fBuffer1;

                sum0 -= *buffer0Cursor;
                *buffer0Cursor = leadingEdge;
                buffer0Cursor = (buffer0Cursor + 1) < fBuffer0End ? buffer0Cursor + 1 : fBuffer0;
            }
        }

    private:
        inline static constexpr uint64_t kHalf = static_cast<uint64_t>(1) << 31;

        uint8_t finalScale(uint32_t sum) const {
            return static_cast<uint8_t>((fWeight * sum + kHalf) >> 32);
        }

        uint64_t  fWeight;
        int       fNoChangeCount;
        uint32_t* fBuffer0;
        uint32_t* fBuffer0End;
        uint32_t* fBuffer1;
        uint32_t* fBuffer1End;
        uint32_t* fBuffer2;
        uint32_t* fBuffer2End;
    };

    Scan makeBlurScan(int width, uint32_t* buffer) const {
        uint32_t* buffer0, *buffer0End, *buffer1, *buffer1End, *buffer2, *buffer2End;
        buffer0 = buffer;
        buffer0End = buffer1 = buffer0 + fPass0Size;
        buffer1End = buffer2 = buffer1 + fPass1Size;
        buffer2End = buffer2 + fPass2Size;
        int noChangeCount = fSlidingWindow > width ? fSlidingWindow - width : 0;

        return Scan(
            fWeight, noChangeCount,
            buffer0, buffer0End,
            buffer1, buffer1End,
            buffer2, buffer2End);
    }

    uint64_t fWeight;
    int      fBorder;
    int      fSlidingWindow;
    int      fPass0Size;
    int      fPass1Size;
    int      fPass2Size;
};


}}
