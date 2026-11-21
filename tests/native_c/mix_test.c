/* Host test of native/src/mix.c: mix_run against a one-frame-at-a-time reference, over channel counts, steps (including
 * pitch changes and 48 kHz ratios), start fractions and volumes. Prints "mix: N cases ok" or the first mismatch. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "../../native/src/mix.h"

#define LIMIT 3000

static int16_t data[LIMIT * 2];

static void reference(int ch, long i0, uint32_t frac0, uint32_t step, long cnt, int vol, int32_t *acc) {
    uint64_t pos = ((uint64_t)i0 << 16) | frac0;
    for (long k = 0; k < cnt; k++, pos += step) {
        long idx = (long)(pos >> 16);
        int f = (int)(pos & 0xFFFF), l0, r0, l1, r1;
        if (ch == 2) { l0 = data[idx * 2]; r0 = data[idx * 2 + 1]; l1 = data[idx * 2 + 2]; r1 = data[idx * 2 + 3]; }
        else { l0 = r0 = data[idx]; l1 = r1 = data[idx + 1]; }
        int l = l0 + (((l1 - l0) * f) >> 16), r = r0 + (((r1 - r0) * f) >> 16);
        acc[k * 2] += (l * vol) >> 8;
        acc[k * 2 + 1] += (r * vol) >> 8;
    }
}

int main(void) {
    static const uint32_t steps[] = { 65536, 32768, 131072, 70000, 12345, 3 * 65536 + 7, 60187, 524288, 1 };
    static const int vols[] = { 0, 77, 256, 1024 };
    static const long starts[] = { 0, 1, 500, 2990, 2997 };
    static const uint32_t fracs[] = { 0, 1, 32768, 65535 };
    static const long wants[] = { 1, 7, 1024, 4000 };
    int cases = 0;
    srand(7);
    for (int i = 0; i < LIMIT * 2; i++) data[i] = (int16_t)(rand() % 65536 - 32768);
    for (int ch = 1; ch <= 2; ch++)
    for (unsigned a = 0; a < sizeof steps / sizeof *steps; a++)
    for (unsigned b = 0; b < sizeof vols / sizeof *vols; b++)
    for (unsigned c = 0; c < sizeof starts / sizeof *starts; c++)
    for (unsigned d = 0; d < sizeof fracs / sizeof *fracs; d++)
    for (unsigned e = 0; e < sizeof wants / sizeof *wants; e++) {
        uint32_t step = steps[a], frac = fracs[d];
        long i0 = starts[c], n = wants[e], avail = LIMIT - 1 - i0;
        int32_t *got = calloc((size_t)n * 2 + 2, 4), *want = calloc((size_t)n * 2 + 2, 4);
        long cnt = mix_run(data, ch, i0, frac, step, avail, vols[b], got, n);
        /* the frames it claims must stay inside the buffer, and it must not stop early without a reason */
        long last = i0 + (long)(((uint64_t)frac + (uint64_t)(cnt > 0 ? cnt - 1 : 0) * step) >> 16);
        long next = i0 + (long)(((uint64_t)frac + (uint64_t)cnt * step) >> 16);
        if (cnt < 0 || cnt > n || (cnt > 0 && last + 1 >= LIMIT) || (cnt < n && next + 1 < LIMIT && avail <= 30000)) {
            printf("mix: bad count %ld (n %ld ch %d step %u start %ld frac %u)\n", cnt, n, ch, step, i0, frac);
            return 1;
        }
        reference(ch, i0, frac, step, cnt, vols[b], want);
        if (memcmp(got, want, (size_t)cnt * 8) || got[cnt * 2] != 0 || got[cnt * 2 + 1] != 0) {
            printf("mix: output differs (n %ld ch %d step %u start %ld frac %u vol %d)\n", n, ch, step, i0, frac, vols[b]);
            return 1;
        }
        free(got); free(want);
        cases++;
    }
    printf("mix: %d cases ok\n", cases);
    return 0;
}
