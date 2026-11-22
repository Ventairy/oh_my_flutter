#include "../../../android/src/main/cpp/motion/particle_frozen_pose.h"

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    columns = 4,
    rows = 3,
    particles = columns * rows,
    prefix = 2,
    capacity = particles + prefix,
    sample_count = 4,
};

static const float unused = 7171.0f;
static const int32_t unused_color = 0x12345678;
static const double particle_parameters[10] = {
    0.16, 0.04, 0.55, 0.45, 0.02, 0.08, 0.015, 0.075, 0.003, 0.01,
};
static const float samples[(sample_count + 1) * 4] = {
    1.0f, 255, 0.0f, 0.0f,
    0.9f, 245, 0.2f, 0.4f,
    0.6f, 130, 0.5f, 0.3f,
    0.5f,  80, 0.3f, 0.5f,
    0.4f,   0, 0.0f, 0.0f,
};
static const float x_edges[] = {0, 2.25f, 4.5f, 6.75f, 9};
static const float y_edges[] = {0, 3, 6, 9};
static const double x_centers[] = {-0.875, 1.375, 3.625, 5.875};
static const double y_centers[] = {0.5, 3.5, 6.5};
static const double widths[] = {2.25, 2.25, 2.25, 2.25};
static const double heights[] = {3, 3, 3};
static const double pivot_x = 2.5;
static const double pivot_y = 3.5;

typedef struct {
    float delays[particles];
    float lifetimes[particles];
    float drift_x[particles];
    float drift_y[particles];
    double curl_sines[particles];
    double curl_cosines[particles];
    double scales[particles];
    double opacities[particles];
    double offset_x[particles];
    double offset_y[particles];
} Pose;

typedef struct {
    float transforms[capacity * 4 + 2];
    float rects[capacity * 4 + 2];
    int32_t colors[capacity + 2];
} Atlas;

typedef struct {
    double progress;
    int32_t curl_columns;
    double direction_cosine;
    double direction_sine;
    double suffix_cosine;
    double suffix_sine;
    double suffix_x;
    double suffix_y;
    double suffix_alpha;
} Frame;

static const Frame early_frame = {
    .progress = 0.069,
    .curl_columns = 2,
    .direction_cosine = 0.8,
    .direction_sine = -0.6,
    .suffix_cosine = 1,
    .suffix_alpha = 1,
};

static void require(int condition, const char* message) {
    if (condition) return;
    fprintf(stderr, "Native frozen pose regression: %s\n", message);
    exit(EXIT_FAILURE);
}

static void reset_atlas(Atlas* atlas) {
    for (size_t index = 0; index < capacity * 4 + 2; index++) {
        atlas->transforms[index] = unused;
        atlas->rects[index] = unused;
    }
    for (size_t index = 0; index < capacity + 2; index++) {
        atlas->colors[index] = unused_color;
    }
}

static void require_write_range(
    const Atlas* atlas, int32_t first, int32_t count, int writes_rects
) {
    require(count >= 0 && first >= 0 && first + count <= capacity, "invalid test write range");
    const size_t start = (size_t)first + 1;
    const size_t end = start + (size_t)count;
    for (size_t index = 0; index < capacity + 2; index++) {
        if (index >= start && index < end) continue;
        require(atlas->colors[index] == unused_color, "wrote colors outside the submitted range");
    }
    const size_t component_start = (size_t)first * 4 + 1;
    const size_t component_end = component_start + (size_t)count * 4;
    for (size_t index = 0; index < capacity * 4 + 2; index++) {
        const int outside = index < component_start || index >= component_end;
        if (outside) {
            require(atlas->transforms[index] == unused, "wrote transforms outside the submitted range");
        }
        if (outside || !writes_rects) {
            require(atlas->rects[index] == unused, "overwrote an unsubmitted or reused source rectangle");
        }
    }
}

static int32_t initialize(Pose* pose, Atlas* atlas, Frame frame, int first_dormant_column, int first) {
    return omf_motion_first_pose(
        columns, rows, frame.curl_columns, first, 42, 1, sample_count, first_dormant_column,
        9, frame.progress, frame.direction_cosine, frame.direction_sine,
        pivot_x, pivot_y, frame.suffix_cosine, frame.suffix_sine,
        frame.suffix_x, frame.suffix_y, 1, frame.suffix_alpha,
        particle_parameters, samples, x_centers, y_centers, x_centers, y_centers, widths, heights,
        pose->delays, pose->lifetimes, pose->drift_x, pose->drift_y,
        pose->curl_sines, pose->curl_cosines, pose->scales, pose->opacities,
        pose->offset_x, pose->offset_y, x_edges, y_edges,
        atlas->transforms + 1, atlas->rects + 1, atlas->colors + 1
    );
}

static int32_t advance(
    Pose* pose, Atlas* atlas, Frame frame, int old_curl_columns, int first_dormant_column,
    int omit_zero, int update_pose
) {
    return omf_motion_terminal_pose(
        columns, rows, old_curl_columns, frame.curl_columns, prefix, 1, sample_count,
        first_dormant_column, omit_zero, update_pose, frame.progress, frame.direction_cosine, frame.direction_sine,
        pivot_x, pivot_y, frame.suffix_cosine, frame.suffix_sine,
        frame.suffix_x, frame.suffix_y, 1, frame.suffix_alpha,
        samples, x_centers, y_centers, x_centers, y_centers, widths, heights,
        pose->delays, pose->lifetimes, pose->drift_x, pose->drift_y,
        pose->curl_sines, pose->curl_cosines, pose->scales, pose->opacities,
        pose->offset_x, pose->offset_y, x_edges, y_edges,
        atlas->transforms + 1, atlas->rects + 1, atlas->colors + 1
    );
}

static void require_same_pose(const Atlas* expected, const Atlas* actual) {
    require(memcmp(expected->transforms, actual->transforms, sizeof(actual->transforms)) == 0,
        "retained transforms must match a fresh pose");
    require(memcmp(expected->colors, actual->colors, sizeof(actual->colors)) == 0,
        "retained colors must match a fresh pose");
    require_write_range(actual, prefix, particles, 0);
}

static void test_reversal_and_suffix(void) {
    Pose pose = {0};
    Pose fresh = {0};
    Atlas actual;
    Atlas expected;
    Frame frame = early_frame;
    const int first_dormant_column = 2;

    reset_atlas(&actual);
    const int early_count = initialize(&pose, &actual, frame, first_dormant_column, 0);
    require(early_count == rows * (first_dormant_column + 1), "early draw must merge all dormant row tails");
    require_write_range(&actual, 0, early_count, 1);
    for (int row = 0; row < rows; row++) {
        const int tail_rect = 1 + (row * (first_dormant_column + 1) + first_dormant_column) * 4;
        require(actual.rects[tail_rect] == x_edges[first_dormant_column] &&
            actual.rects[tail_rect + 2] == x_edges[columns],
            "each merged tail must start at the cutoff and reach its source row edge");
    }

    frame.progress = 0.39;
    frame.curl_columns = columns;
    reset_atlas(&actual);
    reset_atlas(&expected);
    require(initialize(&fresh, &expected, frame, -1, prefix) == particles, "fresh draw must cover the full grid");
    require(advance(&pose, &actual, frame, 2, -1, 0, 1) == particles, "advance must cover the full grid");
    require_same_pose(&expected, &actual);

    frame.progress = early_frame.progress;
    frame.direction_cosine = -0.8;
    frame.direction_sine = 0.6;
    reset_atlas(&actual);
    reset_atlas(&expected);
    initialize(&fresh, &expected, frame, -1, prefix);
    require(advance(&pose, &actual, frame, columns, -1, 0, 1) == particles, "reversal must restore the full grid");
    require_same_pose(&expected, &actual);

    const Pose saved = pose;
    frame.suffix_cosine = 0.75;
    frame.suffix_sine = -0.5;
    frame.suffix_x = 1.5;
    frame.suffix_y = -0.25;
    frame.suffix_alpha = 0.74;
    reset_atlas(&actual);
    reset_atlas(&expected);
    initialize(&fresh, &expected, frame, -1, prefix);
    require(advance(&pose, &actual, frame, columns, -1, 0, 0) == particles, "suffix repaint must cover all cells");
    require_same_pose(&expected, &actual);
    require(memcmp(&saved, &pose, sizeof(pose)) == 0, "changing only the suffix must preserve retained pose buffers");
}

static void test_late_prune(void) {
    Pose pose = {0};
    Atlas full;
    Atlas pruned;
    Frame frame = early_frame;
    frame.progress = 0.89;
    frame.curl_columns = columns;
    reset_atlas(&full);
    reset_atlas(&pruned);
    require(initialize(&pose, &full, frame, -1, prefix) == particles, "full draw must retain zero-alpha cells");
    require_write_range(&full, prefix, particles, 1);
    const int count = advance(&pose, &pruned, frame, columns, -1, 1, 0);
    require(count > 0 && count < particles, "late draw must have both surviving and discarded cells");
    require_write_range(&pruned, 0, count, 1);

    int output = 1;
    for (int cell = prefix + 1; cell <= prefix + particles; cell++) {
        if (full.colors[cell] == 0) continue;
        const int source = 1 + (cell - 1) * 4;
        const int target = 1 + (output - 1) * 4;
        require(output <= count && pruned.colors[output] == full.colors[cell] &&
            memcmp(full.transforms + source, pruned.transforms + target, 4 * sizeof(float)) == 0 &&
            memcmp(full.rects + source, pruned.rects + target, 4 * sizeof(float)) == 0,
            "pruning must retain every nonzero cell in draw order");
        output++;
    }
    require(output == count + 1, "returned prune count must equal the surviving cells");
}

int main(void) {
    test_reversal_and_suffix();
    test_late_prune();
    puts("Passed native frozen pose regressions: replay parity, suffix reuse, row merging, pruning and guards.");
    return EXIT_SUCCESS;
}
