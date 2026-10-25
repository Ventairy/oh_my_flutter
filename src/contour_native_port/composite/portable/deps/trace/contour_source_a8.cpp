#include "contour_source_a8.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <new>
#define ct_free contour_source_a8_kernel_free
#define ct_trace_a8 contour_source_a8_kernel_trace
#include "kernel.a8.cpp"
#undef ct_free
#undef ct_trace_a8

namespace {

struct OwnedA8TraceOutput {
    CtOutput value{};
    ~OwnedA8TraceOutput() { contour_source_a8_kernel_free(&value); }
};

uint64_t returnedStorageAllowance(const CtOutput& value) {
    // Each standard vector includes a fixed allocator/container allowance.
    constexpr uint64_t perContour = sizeof(std::vector<double>) + 64;
    if (value.value_count > (UINT64_MAX - 64) / sizeof(double)) throw std::bad_alloc();
    const uint64_t coordinates = value.value_count * sizeof(double) + 64;
    if (value.count > (UINT64_MAX - coordinates) / perContour) throw std::bad_alloc();
    return coordinates + uint64_t(value.count) * perContour;
}

}  // namespace

namespace contour_source {

int32_t traceA8(const uint8_t* alpha, uint32_t width, uint32_t height,
                double sourceRatio, uint64_t maximumWorkingBytes,
                std::vector<std::vector<double>>& contours, uint64_t* peakWorkingBytes) {
    std::vector<std::vector<double>>().swap(contours);
    if (peakWorkingBytes) *peakWorkingBytes = 0;
    if (!alpha || width == 0 || height == 0 || !std::isfinite(sourceRatio) ||
        sourceRatio <= 0 || maximumWorkingBytes == 0) return 2;
    // Check before multiplying: extreme uint32 axes can overflow uint64 padding.
    const uint64_t columns = uint64_t(width) + 2, rows = uint64_t(height) + 2;
    if (columns > uint64_t(UINT32_MAX) / rows) return 2;

    Budget budget;
    budget.limit = maximumWorkingBytes;
    BudgetScope scope(&budget);
    // This output must retire before both BudgetScope and its stack Budget.
    OwnedA8TraceOutput traced;
    uint64_t peak = 0;
    int32_t status = 3;
    try {
        status = contour_source_a8_kernel_trace(alpha, uint64_t(width) * height, width, height, sourceRatio, &traced.value);
        peak = budget.peak.load();
        if (status == 0) {
            const auto& value = traced.value;
            const uint64_t additional = returnedStorageAllowance(value);
            const uint64_t live = budget.live.load();
            if (live > maximumWorkingBytes || additional > maximumWorkingBytes - live)
                throw std::bad_alloc();
            contours.reserve(value.count);
            uint64_t offset = 0;
            uint64_t returned = 64 + uint64_t(contours.capacity()) * sizeof(std::vector<double>);
            for (uint32_t index = 0; index < value.count; index++) {
                const uint32_t length = value.lengths[index];
                contours.emplace_back(value.values + offset, value.values + offset + length);
                offset += length;
                const uint64_t next = uint64_t(contours.back().capacity()) * sizeof(double) + 64;
                if (next > UINT64_MAX - returned) throw std::bad_alloc();
                returned += next;
                if (returned > maximumWorkingBytes - live) throw std::bad_alloc();
                peak = std::max(peak, live + returned);
            }
            peak = std::max(peak, live + returned);
        }
    } catch (...) {
        status = 3;
    }
    if (status != 0) std::vector<std::vector<double>>().swap(contours);
    if (peakWorkingBytes) *peakWorkingBytes = std::max(peak, budget.peak.load());
    return status;
}

}  // namespace contour_source
