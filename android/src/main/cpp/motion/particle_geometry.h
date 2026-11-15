#ifndef CATAQUI_PARTICLE_GEOMETRY_H
#define CATAQUI_PARTICLE_GEOMETRY_H

#include <stdint.h>

// The caller owns output and supplies columns * rows * 10 floats.
// Coefficients: columnDelay, randomDelay, lifetimeBase, lifetimeRange,
// xDriftBase, xDriftRange, yDriftBase, yDriftRange, curlBase, curlRange.
void particle_geometry_fill(float* output, int width, int height, int columns,
                           int rows, uint32_t seed, const double motion[10]);

#endif
