#include "mix.h"

long mix_run(const int16_t *d, int ch, long i0, uint32_t frac0, uint32_t step, long avail, int vol, int32_t *acc, long n) {
    if (avail <= 0 || n <= 0 || step == 0) return 0;
    if (avail > 30000) avail = 30000;                 /* keeps avail << 16 inside 32 bits; the caller comes back for the rest */
    uint32_t lim = (uint32_t)avail << 16;
    if (lim <= frac0) return 0;
    uint32_t cnt = (lim - frac0 - 1) / step + 1;      /* frames k with ((frac0 + k * step) >> 16) < avail */
    if ((long)cnt > n) cnt = (uint32_t)n;

    if (ch == 2) {
        if (step == 65536 && frac0 == 0) {
            const int16_t *p = d + i0 * 2;
            for (uint32_t k = 0; k < cnt; k++) {
                acc[k * 2] += (p[k * 2] * vol) >> 8;
                acc[k * 2 + 1] += (p[k * 2 + 1] * vol) >> 8;
            }
        } else {
            uint32_t loc = frac0;
            for (uint32_t k = 0; k < cnt; k++, loc += step) {
                const int16_t *p = d + (i0 + (long)(loc >> 16)) * 2;
                int f = (int)(loc & 0xFFFF);
                int l = p[0] + (((p[2] - p[0]) * f) >> 16), r = p[1] + (((p[3] - p[1]) * f) >> 16);
                acc[k * 2] += (l * vol) >> 8;
                acc[k * 2 + 1] += (r * vol) >> 8;
            }
        }
    } else {
        uint32_t loc = frac0;
        for (uint32_t k = 0; k < cnt; k++, loc += step) {
            const int16_t *p = d + i0 + (long)(loc >> 16);
            int f = (int)(loc & 0xFFFF);
            int v = (((p[0] + (((p[1] - p[0]) * f) >> 16)) * vol) >> 8);
            acc[k * 2] += v;
            acc[k * 2 + 1] += v;
        }
    }
    return (long)cnt;
}
