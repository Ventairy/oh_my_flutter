#include "particle_geometry.h"

static double next_uniform(uint32_t* state) {
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return (double) value * (1.0 / 4294967296.0);
}

void particle_geometry_fill(float* output, int width, int height, int columns,
                           int rows, uint32_t seed, const double motion[10]) {
    const double cell_width = (double) width / columns;
    const double cell_height = (double) height / rows;
    const double column_delay_step = motion[0] / columns;
    const double full_turn = 6.283185307179586476925286766559;
    uint32_t random_state = seed;
    for (int row = 0; row < rows; row++) {
        for (int column = 0; column < columns; column++) {
            output[0] = (float) (column * cell_width);
            output[1] = (float) (row * cell_height);
            output[2] = (float) ((column + 1) * cell_width);
            output[3] = (float) ((row + 1) * cell_height);
            const double delay = column * column_delay_step + next_uniform(&random_state) * motion[1];
            output[4] = (float) delay;
            output[5] = (float) (motion[2] + next_uniform(&random_state) * (motion[3] - delay));
            output[6] = (float) (-width * (motion[4] + next_uniform(&random_state) * motion[5]));
            output[7] = (float) (-width * (motion[6] + next_uniform(&random_state) * motion[7]));
            output[8] = (float) (next_uniform(&random_state) * full_turn);
            output[9] = (float) (width * (motion[8] + next_uniform(&random_state) * motion[9]));
            output += 10;
        }
    }
}
