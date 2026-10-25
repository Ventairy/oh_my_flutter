#ifndef CONTOUR_SCANLINE_H
#define CONTOUR_SCANLINE_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Physical-pixel segments [ax,ay,bx,by] forming closed filled contours.
 * Owns a copy. EO=0;NZ=1;ClipperPositive=2;ClipperNegative=3. Partial coincident cancelled edges
 * require admission normalization. Status0success,1invalid,2allocation,3budget,4cancelled. */
void *sc_create(const double *segments, int32_t count, int32_t fill_rule, int32_t *status);
void sc_destroy(void *context);
/* Adapter accounting only: owned context capacities, excluding allocator headers. */
uint64_t sc_owned_context_bytes(const void *context);
typedef int32_t (*sc_cancel_fn)(void *user);
typedef struct sc_stats {
  uint64_t segment_visits, crossings, intervals, sort_comparisons, subrows, pixel_writes,
      max_active, scratch_bytes;
} sc_stats;
/* Packed caller-owned A8; partial output on failure must be discarded. Native
 * cancellation only, never a Dart callback. No scratch is shared by renders. */
int32_t sc_render(const void *context, int32_t width, int32_t height, double radius,
                  int32_t vertical_aa, uint8_t *output, sc_cancel_fn cancel, void *user,
                  sc_stats *stats);
#ifdef __cplusplus
}
#endif
#endif
