#ifndef MIX_H
#define MIX_H
#include <stdint.h>

/* Mixes one source into the stereo int32 accumulator `acc` for as long as the interpolation only reads samples inside
 * the buffer, and returns the output frames it wrote (0 when the next frame needs a sample past the end, which the
 * caller handles one frame at a time).
 *
 *   d, ch      16-bit samples, interleaved, ch is 1 or 2
 *   i0, frac0  the first source frame to read and its 16.16 fraction
 *   step       source frames per output frame, 16.16
 *   avail      source frames after i0 that can still be read next to a following frame (buffer frames - 1 - i0)
 *   vol        0..1024, 256 is unity
 *   n          output frames wanted
 * No platform headers: tests/native_c/mix_test.c compiles this file on the host. */
long mix_run(const int16_t *d, int ch, long i0, uint32_t frac0, uint32_t step, long avail, int vol, int32_t *acc, long n);

#endif
