#include "particle_frozen_pose.h"
#include <math.h>
#include <string.h>

static double next_uniform(uint32_t* state) {
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return (double)value * (1.0 / 4294967296.0);
}

static inline double interpolate(const float* a, const float* b, int field, double fraction) {
    const double lower = a[field];
    const double upper = b[field];
    return lower + (upper - lower) * fraction;
}

__attribute__((visibility("default")))
int32_t omf_motion_first_pose(
    int32_t columns, int32_t rows, int32_t curl_columns, int32_t first_particle,
    uint32_t seed, int32_t moves, int32_t sample_count, int32_t first_dormant_column,
    double width, double progress, double direction_cosine, double direction_sine,
    double pivot_x, double pivot_y, double suffix_cosine, double suffix_sine,
    double suffix_x, double suffix_y, double sprite_scale, double suffix_alpha,
    const double* restrict motion, const float* restrict samples,
    const double* restrict column_centers, const double* restrict row_centers,
    const double* restrict tile_centers_x, const double* restrict tile_centers_y,
    const double* restrict tile_widths, const double* restrict tile_heights,
    float* restrict delays, float* restrict lifetimes,
    float* restrict x_drifts, float* restrict y_drifts,
    double* restrict curl_sines, double* restrict curl_cosines,
    double* restrict scales, double* restrict opacities,
    double* restrict offsets_x, double* restrict offsets_y,
    const float* restrict horizontal_edges, const float* restrict vertical_edges,
    float* restrict transforms, float* restrict rects, int32_t* restrict colors
) {
    int32_t i = 0;
    int32_t count = 0;
    uint32_t random_state = seed;
    for (int32_t row = 0; row < rows; row++) {
        const double anchor_y = row_centers[row];
        const double tile_y = tile_centers_y[row];
        const double half_height = tile_heights[row] / 2;
        for (int32_t column = 0; column < columns; column++, i++) {
            const double delay =
                ((double)column / columns) * motion[0] +
                next_uniform(&random_state) * motion[1];
            const float rounded_delay = (float)delay;
            const float lifetime = (float)(
                motion[2] + next_uniform(&random_state) * (motion[3] - delay)
            );
            const float x_drift = (float)(
                -width * (motion[4] + next_uniform(&random_state) * motion[5])
            );
            const float y_drift = (float)(
                -width * (motion[6] + next_uniform(&random_state) * motion[7])
            );
            const double angle = (double)(float)(
                next_uniform(&random_state) * 3.141592653589793 * 2
            );
            const double radius = (double)(float)(
                width * (motion[8] + next_uniform(&random_state) * motion[9])
            );
            delays[i] = rounded_delay;
            lifetimes[i] = lifetime;
            x_drifts[i] = x_drift;
            y_drifts[i] = y_drift;

            double particle_curl_sine = angle;
            double particle_curl_cosine = radius;
            if (column < curl_columns) {
                particle_curl_sine = sin(angle) * radius;
                particle_curl_cosine = cos(angle) * radius;
            }
            curl_sines[i] = particle_curl_sine;
            curl_cosines[i] = particle_curl_cosine;

            double shape_scale = 1;
            double opacity = 1;
            double offset_x = 0;
            double offset_y = 0;
            const double elapsed = progress - rounded_delay;
            if (elapsed > 0) {
                const double normalized = elapsed / lifetime;
                const double life = normalized < 1 ? normalized : 1;
                const double position = life * sample_count;
                const int32_t index = (int32_t)position;
                const float* from = samples + index * 4;
                const float* next = index == sample_count ? from : from + 4;
                const double fraction = position - index;
                shape_scale = interpolate(from, next, 0, fraction);
                opacity = interpolate(from, next, 1, fraction) / 255;
                if (moves) {
                    const double sine = interpolate(from, next, 2, fraction);
                    const double cosine = interpolate(from, next, 3, fraction);
                    const double x =
                        x_drift * life +
                        particle_curl_sine * cosine +
                        particle_curl_cosine * sine;
                    const double y =
                        y_drift * life +
                        particle_curl_cosine * cosine -
                        particle_curl_sine * sine;
                    offset_x = x * direction_cosine - y * direction_sine;
                    offset_y = x * direction_sine + y * direction_cosine;
                }
            }
            scales[i] = shape_scale;
            opacities[i] = opacity;
            offsets_x[i] = offset_x;
            offsets_y[i] = offset_y;

            if (first_dormant_column >= 0 && column > first_dormant_column) {
                continue;
            }
            const uint32_t alpha = (uint32_t)lround(opacity * suffix_alpha * 255);
            if (first_dormant_column >= 0 && alpha == 0) {
                continue;
            }
            const double anchor_x = column_centers[column];
            const double x =
                anchor_x + (tile_centers_x[column] - anchor_x) * shape_scale + offset_x - pivot_x;
            const double y = anchor_y + (tile_y - anchor_y) * shape_scale + offset_y - pivot_y;
            const double a = suffix_cosine * shape_scale;
            const double b = suffix_sine * shape_scale;
            const double half_width = tile_widths[column] / 2;
            const int32_t target = first_particle + count++;
            float* output = transforms + target * 4;
            output[0] = (float)(a * sprite_scale);
            output[1] = (float)(b * sprite_scale);
            output[2] = (float)((suffix_cosine * x - suffix_sine * y + pivot_x + suffix_x)
                - a * half_width + b * half_height);
            output[3] = (float)((suffix_sine * x + suffix_cosine * y + pivot_y + suffix_y)
                - b * half_width - a * half_height);
            float* rect = rects + target * 4;
            rect[0] = horizontal_edges[column];
            rect[1] = vertical_edges[row];
            rect[2] = horizontal_edges[column == first_dormant_column ? columns : column + 1];
            rect[3] = vertical_edges[row + 1];
            const uint32_t color = alpha << 24;
            memcpy(colors + target, &color, sizeof(color));
        }
    }
    return count;
}

__attribute__((visibility("default")))
int32_t omf_motion_terminal_pose(
    int32_t columns, int32_t rows, int32_t former_curl_columns, int32_t curl_columns,
    int32_t first_particle, int32_t moves, int32_t sample_count,
    int32_t first_dormant_column, int32_t omit_zero, int32_t update_pose,
    double progress, double direction_cosine, double direction_sine,
    double pivot_x, double pivot_y, double suffix_cosine, double suffix_sine,
    double suffix_x, double suffix_y, double sprite_scale, double suffix_alpha,
    const float* restrict samples,
    const double* restrict column_centers, const double* restrict row_centers,
    const double* restrict tile_centers_x, const double* restrict tile_centers_y,
    const double* restrict tile_widths, const double* restrict tile_heights,
    const float* restrict delays, const float* restrict lifetimes,
    const float* restrict x_drifts, const float* restrict y_drifts,
    double* restrict curl_sines, double* restrict curl_cosines,
    double* restrict scales, double* restrict opacities,
    double* restrict offsets_x, double* restrict offsets_y,
    const float* restrict horizontal_edges, const float* restrict vertical_edges,
    float* restrict transforms, float* restrict rects, int32_t* restrict colors
) {
    int32_t i = 0;
    int32_t count = 0;
    for (int32_t row = 0; row < rows; row++) {
        const double anchor_y = row_centers[row];
        const double tile_y = tile_centers_y[row];
        const double half_height = tile_heights[row] / 2;
        for (int32_t column = 0; column < columns; column++, i++) {
            double shape_scale = scales[i];
            double opacity = opacities[i];
            double offset_x = offsets_x[i];
            double offset_y = offsets_y[i];
            if (update_pose) {
                if (column >= former_curl_columns && column < curl_columns) {
                    const double angle = curl_sines[i];
                    const double radius = curl_cosines[i];
                    curl_sines[i] = sin(angle) * radius;
                    curl_cosines[i] = cos(angle) * radius;
                }
                shape_scale = 1;
                opacity = 1;
                offset_x = 0;
                offset_y = 0;
                const double elapsed = progress - delays[i];
                if (elapsed > 0) {
                    const double normalized = elapsed / lifetimes[i];
                    const double life = normalized < 1 ? normalized : 1;
                    const double position = life * sample_count;
                    const int32_t index = (int32_t)position;
                    const float* from = samples + index * 4;
                    const float* next = index == sample_count ? from : from + 4;
                    const double fraction = position - index;
                    shape_scale = interpolate(from, next, 0, fraction);
                    opacity = interpolate(from, next, 1, fraction) / 255;
                    if (moves) {
                        const double sine = interpolate(from, next, 2, fraction);
                        const double cosine = interpolate(from, next, 3, fraction);
                        const double x =
                            x_drifts[i] * life +
                            curl_sines[i] * cosine +
                            curl_cosines[i] * sine;
                        const double y =
                            y_drifts[i] * life +
                            curl_cosines[i] * cosine -
                            curl_sines[i] * sine;
                        offset_x = x * direction_cosine - y * direction_sine;
                        offset_y = x * direction_sine + y * direction_cosine;
                    }
                }
                scales[i] = shape_scale;
                opacities[i] = opacity;
                offsets_x[i] = offset_x;
                offsets_y[i] = offset_y;
            }

            if (first_dormant_column >= 0 && column > first_dormant_column) {
                continue;
            }
            const uint32_t alpha = (uint32_t)lround(opacity * suffix_alpha * 255);
            if ((first_dormant_column >= 0 || omit_zero) && alpha == 0) {
                continue;
            }
            const double anchor_x = column_centers[column];
            const double x =
                anchor_x + (tile_centers_x[column] - anchor_x) * shape_scale + offset_x - pivot_x;
            const double y = anchor_y + (tile_y - anchor_y) * shape_scale + offset_y - pivot_y;
            const double a = suffix_cosine * shape_scale;
            const double b = suffix_sine * shape_scale;
            const double half_width = tile_widths[column] / 2;
            const int32_t target = (first_dormant_column >= 0 || omit_zero ? 0 : first_particle) + count++;
            float* output = transforms + target * 4;
            output[0] = (float)(a * sprite_scale);
            output[1] = (float)(b * sprite_scale);
            output[2] = (float)((suffix_cosine * x - suffix_sine * y + pivot_x + suffix_x)
                - a * half_width + b * half_height);
            output[3] = (float)((suffix_sine * x + suffix_cosine * y + pivot_y + suffix_y)
                - b * half_width - a * half_height);
            if (first_dormant_column >= 0 || omit_zero) {
                float* rect = rects + target * 4;
                rect[0] = horizontal_edges[column];
                rect[1] = vertical_edges[row];
                rect[2] = horizontal_edges[column == first_dormant_column ? columns : column + 1];
                rect[3] = vertical_edges[row + 1];
            }
            const uint32_t color = alpha << 24;
            memcpy(colors + target, &color, sizeof(color));
        }
    }
    return count;
}
