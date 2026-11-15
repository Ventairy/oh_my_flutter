#include "../../../android/src/main/cpp/motion/particle_geometry.h"

#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

_Static_assert(sizeof(float) == 4 && FLT_MANT_DIG == 24, "The particle protocol requires Float32.");

typedef struct {
    float* allocation;
    float* particles;
    size_t count;
} GuardedGeometry;

static void require(int condition, const char* message) {
    if (condition) return;
    fprintf(stderr, "Native geometry regression: %s\n", message);
    exit(EXIT_FAILURE);
}

static uint32_t float_bits(float value) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static GuardedGeometry allocate_geometry(int columns, int rows) {
    const size_t count = (size_t) columns * (size_t) rows;
    float* allocation = malloc((count * 10 + 2) * sizeof(float));
    require(allocation != NULL, "test allocation failed");
    allocation[0] = 123.0f;
    allocation[count * 10 + 1] = 456.0f;
    return (GuardedGeometry) {allocation, allocation + 1, count};
}

static void require_guards(const GuardedGeometry* geometry) {
    require(geometry->allocation[0] == 123.0f, "generation wrote before the output buffer");
    require(geometry->allocation[geometry->count * 10 + 1] == 456.0f,
        "generation wrote after the output buffer");
}

static void test_unrounded_lifetime(const GuardedGeometry* geometry) {
    // Independent double-precision reference: rounding delay first produces 0x3f27c0e7 instead.
    require(float_bits(geometry->particles[69 * 10 + 5]) == 0x3f27c0e6U,
        "the unrounded double delay must feed the lifetime calculation");
}

static void test_reference_particles(const GuardedGeometry* geometry) {
    // Fixed packets from an independent XorShift32/double-precision reference, not production output.
    const struct {
        size_t index;
        uint32_t attributes[10];
    } expected[] = {
        {0, {0x00000000U, 0x00000000U, 0x406c34c9U, 0x406daa35U, 0x38ddc929U,
            0x3f58d99eU, 0xc12567acU, 0xc1e167faU, 0x40b0047dU, 0x4011a195U}},
        {1, {0x406c34c9U, 0x00000000U, 0x40ec34c9U, 0x406daa35U, 0x3d1469efU,
            0x3f48c528U, 0xc1dfbb49U, 0xc140ac24U, 0x408bed0fU, 0x4078feebU}},
        {96, {0x43b12796U, 0x00000000U, 0x43b30000U, 0x406daa35U, 0x3e23fae8U,
            0x3f0e1682U, 0xc1a196d5U, 0xc11f847dU, 0x4088da76U, 0x40423a96U}},
        {97, {0x00000000U, 0x406daa35U, 0x406c34c9U, 0x40edaa35U, 0x3c40f019U,
            0x3f603a0cU, 0xc130bdacU, 0xc1594accU, 0x402382ddU, 0x4082ce96U}},
        {17944, {0x43b12796U, 0x442ad256U, 0x43b30000U, 0x442bc000U, 0x3e432554U,
            0x3f4246ccU, 0xc20a899eU, 0xc1cf6e51U, 0x3f55c389U, 0x407716a9U}},
    };
    for (size_t packet = 0; packet < sizeof(expected) / sizeof(expected[0]); packet++) {
        const float* particle = geometry->particles + expected[packet].index * 10;
        for (size_t attribute = 0; attribute < 10; attribute++) {
            require(float_bits(particle[attribute]) == expected[packet].attributes[attribute],
                "a fixed particle packet changed");
        }
    }
}

static void test_ranges_and_tiling(const GuardedGeometry* geometry) {
    require(geometry->count == 17945 && geometry->count <= 18000, "the reference grid exceeds its particle budget");
    for (size_t index = 0; index < geometry->count; index++) {
        const float* particle = geometry->particles + index * 10;
        for (size_t attribute = 0; attribute < 10; attribute++) {
            require(isfinite(particle[attribute]), "all particle attributes must be finite");
        }
        require(particle[0] >= 0 && particle[2] <= 358 && particle[2] > particle[0],
            "source rectangles must stay within the image width");
        require(particle[1] >= 0 && particle[3] <= 687 && particle[3] > particle[1],
            "source rectangles must stay within the image height");
        const double column_delay = (double) (index % 97) / 97 * 0.16;
        require(particle[4] >= column_delay - 0.000001 && particle[4] < column_delay + 0.040001,
            "delay must combine its column offset and bounded random delay");
        require(particle[5] >= 0.55f && particle[5] <= 1.0f - particle[4] + 0.000001f,
            "lifetime must fit the remaining animation interval");
        require(particle[6] <= -358 * 0.02 && particle[6] >= -358 * 0.10,
            "horizontal drift must stay in the authored range");
        require(particle[7] <= -358 * 0.015 && particle[7] >= -358 * 0.09,
            "vertical drift must stay in the authored range");
        require(particle[8] >= 0 && particle[8] < 6.283185307179587,
            "curl phase must span one turn");
        require(particle[9] >= 358 * 0.003 && particle[9] <= 358 * 0.013,
            "curl amplitude must stay in the authored range");
        if (index % 97 != 0) {
            require(particle[0] == particle[-10 + 2], "adjacent source columns must share an edge");
        }
        if (index >= 97) {
            require(particle[1] == particle[-97 * 10 + 3], "adjacent source rows must share an edge");
        }
    }
    const float* last = geometry->particles + (geometry->count - 1) * 10;
    require(geometry->particles[0] == 0 && geometry->particles[1] == 0 && last[2] == 358 && last[3] == 687,
        "the grid must cover the complete captured image");
    require_guards(geometry);
}

static void test_seed_contract(const GuardedGeometry* reference, const double motion[10]) {
    GuardedGeometry repeated = allocate_geometry(97, 185);
    particle_geometry_fill(repeated.particles, 358, 687, 97, 185, 42, motion);
    const size_t bytes = reference->count * 10 * sizeof(float);
    require(memcmp(reference->particles, repeated.particles, bytes) == 0,
        "the same seed must reproduce the complete particle packet");
    particle_geometry_fill(repeated.particles, 358, 687, 97, 185, 43, motion);
    require(memcmp(reference->particles, repeated.particles, bytes) != 0,
        "a different seed must change particle motion");
    for (size_t index = 0; index < reference->count; index++) {
        require(memcmp(reference->particles + index * 10, repeated.particles + index * 10, 4 * sizeof(float)) == 0,
            "changing the seed must preserve source-cell geometry");
    }
    require_guards(&repeated);
    free(repeated.allocation);
}

static void test_caller_supplied_motion(void) {
    GuardedGeometry geometry = allocate_geometry(2, 2);
    const double motion[10] = {0, 0, 0.4, 0.6, 0.1, 0, 0.2, 0, 0.01, 0};
    particle_geometry_fill(geometry.particles, 10, 20, 2, 2, 42, motion);
    for (size_t index = 0; index < geometry.count; index++) {
        const float* particle = geometry.particles + index * 10;
        require(particle[4] == 0, "zero delay inputs must remove both delay components");
        require(particle[5] >= 0.4f && particle[5] <= 1.0f, "lifetime must use the supplied base and range");
        require(particle[6] == -1.0f && particle[7] == -2.0f,
            "drift must use caller values rather than embedded defaults");
        require(particle[9] == 0.1f, "curl amplitude must use caller values");
    }
    require_guards(&geometry);
    free(geometry.allocation);
}

static void test_grid_sizes(const double motion[10]) {
    const struct { int width, height, columns, rows; } cases[] = {
        {1, 1, 1, 1}, {25, 90, 7, 23}, {1000, 1, 313, 1}, {412, 891, 91, 197},
    };
    for (size_t index = 0; index < sizeof(cases) / sizeof(cases[0]); index++) {
        GuardedGeometry geometry = allocate_geometry(cases[index].columns, cases[index].rows);
        require(geometry.count <= 18000, "the test grid must respect the particle budget");
        particle_geometry_fill(geometry.particles, cases[index].width, cases[index].height,
            cases[index].columns, cases[index].rows, 42, motion);
        const float* last = geometry.particles + (geometry.count - 1) * 10;
        require(geometry.particles[0] == 0 && geometry.particles[1] == 0,
            "all grid sizes must begin at the image origin");
        require(last[2] == cases[index].width && last[3] == cases[index].height,
            "all grid sizes must reach the image's far edge");
        require_guards(&geometry);
        free(geometry.allocation);
    }
}

int main(void) {
    const double motion[10] = {0.16, 0.04, 0.55, 0.45, 0.02, 0.08, 0.015, 0.075, 0.003, 0.01};
    GuardedGeometry geometry = allocate_geometry(97, 185);
    particle_geometry_fill(geometry.particles, 358, 687, 97, 185, 42, motion);
    test_unrounded_lifetime(&geometry);
    test_reference_particles(&geometry);
    test_ranges_and_tiling(&geometry);
    test_seed_contract(&geometry, motion);
    test_caller_supplied_motion();
    test_grid_sizes(motion);
    free(geometry.allocation);
    puts("Passed native geometry regressions: packets, ranges, tiling, seeds, precision, inputs and guards.");
    return EXIT_SUCCESS;
}
