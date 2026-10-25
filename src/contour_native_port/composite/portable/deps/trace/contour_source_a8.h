#ifndef CONTOUR_SOURCE_A8_H
#define CONTOUR_SOURCE_A8_H

#include <cstdint>
#include <vector>

namespace contour_source {

// Traces width*height tightly packed alpha bytes, without creating RGBA pixels.
// sourceRatio controls the unchanged visibility and simplification rules.
// Coordinates remain physical pixels and contours use even-odd filling.
//
// Returns 0 on success, 1 on geometry capacity, 2 for unsupported arguments,
// or 3 when working capacity/allocation fails. Replaces contours on every call.
// The input is borrowed for this synchronous call. Returned standard vectors
// own their storage and do not retain a pointer to the temporary kernel budget.
// maximumWorkingBytes covers tracked kernel storage and a conservative returned
// vector storage allowance while copying. The borrowed input is caller-owned.
int32_t traceA8(const uint8_t* alpha,
                uint32_t width,
                uint32_t height,
                double sourceRatio,
                uint64_t maximumWorkingBytes,
                std::vector<std::vector<double>>& contours,
                uint64_t* peakWorkingBytes = nullptr);

}  // namespace contour_source

#endif
