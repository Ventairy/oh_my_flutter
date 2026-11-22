#ifndef OMF_PARTICLE_FROZEN_POSE_H
#define OMF_PARTICLE_FROZEN_POSE_H

#include <stdint.h>

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
);

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
);

#endif
