/* Balatro PSP native engine: GPU sprites (tiled textures), polygons, TTF text, input, fs, zlib. */
#include <pspkernel.h>
#include <pspdisplay.h>
#include <pspgu.h>
#include <pspctrl.h>
#include <psppower.h>
#include <pspsysmem.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pspmath.h>
#include <malloc.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <zlib.h>
#include "lua.h"
#include "lauxlib.h"

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#define STBI_NO_STDIO
#include "stb_image.h"
#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"

#define SCR_W 480
#define SCR_H 272
#define TILE_MAX 512
#define GU_LIST_WORDS (1024 * 1024)

static void trace(const char *what);
static unsigned int __attribute__((aligned(16))) gu_list[GU_LIST_WORDS];

/* ---------------------------------------------------------------- textures */
/* fmt: 0 = RGBA8888, 1 = 8-bit indices + CLUT (256 entries), 2 = 4-bit indices + CLUT (16 entries). Pixel-art sheets
   almost always have <= 256 colours, so they are stored paletted (4x / 8x less RAM, and less texture bandwidth). */
typedef struct { int x0, y0, w, h, pw, ph; uint32_t *px; int fmt; const uint32_t *clut; } Tile;
typedef struct { int w, h, ntx, nty, linear; Tile *tiles; uint32_t *clut; size_t bytes; unsigned vram_off; } Tex;   /* vram_off != 0: canvas (pixels live in VRAM) */
static size_t tex_bytes_total = 0;
static int use_palette = 1;          /* native.palette(false) stores everything as RGBA8888 (A/B and fallback) */   /* live texture RAM (pixels + palettes), for telemetry */

static void flush_batch(void);
static const uint32_t *bound_px; static const uint32_t *bound_clut;
static int pow2ge(int n) { int p = 8; while (p < n) p <<= 1; return p; }

/* ---- VRAM pool for canvases: what is left after the two 480x272 RGBA screen buffers (0x000000-0x110000) */
#define VRAM_BASE 0x04000000u
#define VRAM_POOL_START 0x110000u
#define VRAM_POOL_END 0x200000u
#define CANVAS_STRIDE 512
typedef struct { unsigned off, size; int used; } VBlock;
static VBlock vblk[32]; static int nvblk = 0;
static unsigned vram_alloc(unsigned size) {
    if (!nvblk) { vblk[0].off = VRAM_POOL_START; vblk[0].size = VRAM_POOL_END - VRAM_POOL_START; vblk[0].used = 0; nvblk = 1; }
    size = (size + 2047) & ~2047u;
    for (int i = 0; i < nvblk; i++) if (!vblk[i].used && vblk[i].size >= size) {
        if (vblk[i].size > size && nvblk < 32) {
            memmove(&vblk[i + 2], &vblk[i + 1], (nvblk - i - 1) * sizeof(VBlock)); nvblk++;
            vblk[i + 1].off = vblk[i].off + size; vblk[i + 1].size = vblk[i].size - size; vblk[i + 1].used = 0;
            vblk[i].size = size;
        }
        vblk[i].used = 1; return vblk[i].off;
    }
    return 0;
}
static void vram_free(unsigned off) {
    for (int i = 0; i < nvblk; i++) if (vblk[i].off == off && vblk[i].used) {
        vblk[i].used = 0;
        if (i + 1 < nvblk && !vblk[i + 1].used) { vblk[i].size += vblk[i + 1].size; memmove(&vblk[i + 1], &vblk[i + 2], (nvblk - i - 2) * sizeof(VBlock)); nvblk--; }
        if (i > 0 && !vblk[i - 1].used) { vblk[i - 1].size += vblk[i].size; memmove(&vblk[i], &vblk[i + 1], (nvblk - i - 1) * sizeof(VBlock)); nvblk--; }
        return;
    }
}
static Tex *cur_target = NULL;     /* canvas being drawn to (NULL = screen) */
static unsigned screen_draw_off = 0;   /* offset of the screen buffer currently drawn to (toggles on swap) */
static int suppress_draw = 0;      /* a canvas that could not get VRAM: drop draws instead of corrupting the screen */

static void tex_free(Tex *t) {
    if (!t || !t->tiles) return;
    flush_batch();                       /* pending draws may still point at these pixels */
    bound_px = NULL; bound_clut = NULL;
    if (t->vram_off) { if (cur_target == t) cur_target = NULL; vram_free(t->vram_off); t->vram_off = 0; }
    else for (int i = 0; i < t->ntx * t->nty; i++) free(t->tiles[i].px);
    free(t->tiles); t->tiles = NULL;
    free(t->clut); t->clut = NULL;
    tex_bytes_total -= t->bytes; t->bytes = 0;
}
static int tex_gc(lua_State *L) { tex_free((Tex *)luaL_checkudata(L, 1, "balatro.tex")); return 0; }

static int l_image_load(lua_State *L) { trace("imgload");
    size_t len; const char *path = luaL_checkstring(L, 1);
    FILE *f = fopen(path, "rb");
    if (!f) { lua_pushnil(L); lua_pushfstring(L, "cannot open %s", path); return 2; }
    fseek(f, 0, SEEK_END); len = ftell(f); fseek(f, 0, SEEK_SET);
    unsigned char *buf = malloc(len);
    if (!buf || fread(buf, 1, len, f) != len) { fclose(f); free(buf); lua_pushnil(L); lua_pushstring(L, "read error"); return 2; }
    fclose(f);
    int w, h, n;
    unsigned char *img = stbi_load_from_memory(buf, (int)len, &w, &h, &n, 4);
    free(buf);
    if (!img) { lua_pushnil(L); lua_pushfstring(L, "decode failed: %s", stbi_failure_reason()); return 2; }
    /* count distinct colours (alpha-0 pixels all count as one) to pick RGBA8888 / T8 / T4 */
    uint32_t pal[256]; int npal = 0, paletted = 1;
    {
        static uint32_t hk[1024]; static short hv[1024];
        memset(hv, -1, sizeof hv);
        size_t np = (size_t)w * h; uint32_t *px32 = (uint32_t *)img;
        for (size_t i = 0; i < np && paletted; i++) {
            uint32_t c = px32[i]; if ((c >> 24) == 0) c = 0;
            unsigned hsh = (c * 2654435761u) >> 22;
            for (;;) {
                if (hv[hsh] < 0) { if (npal == 256) { paletted = 0; break; } hk[hsh] = c; hv[hsh] = (short)npal; pal[npal++] = c; break; }
                if (hk[hsh] == c) break;
                hsh = (hsh + 1) & 1023;
            }
        }
    }
    int fmt = (!paletted || !use_palette) ? 0 : npal <= 16 ? 2 : 1;
    Tex *t = lua_newuserdata(L, sizeof(Tex));
    memset(t, 0, sizeof *t);
    luaL_getmetatable(L, "balatro.tex"); lua_setmetatable(L, -2);
    t->w = w; t->h = h;
    t->ntx = (w + TILE_MAX - 1) / TILE_MAX; t->nty = (h + TILE_MAX - 1) / TILE_MAX;
    t->tiles = calloc(t->ntx * t->nty, sizeof(Tile));
    t->linear = 0;
    if (fmt) {
        t->clut = memalign(16, 256 * 4); memset(t->clut, 0, 256 * 4);
        memcpy(t->clut, pal, npal * 4);
        sceKernelDcacheWritebackRange(t->clut, 256 * 4);
        t->bytes += 256 * 4;
    }
    /* lookup colour -> index for the conversion pass */
    static uint32_t ck[1024]; static short cv[1024];
    if (fmt) {
        memset(cv, -1, sizeof cv);
        for (int i = 0; i < npal; i++) { unsigned hsh = (pal[i] * 2654435761u) >> 22; while (cv[hsh] >= 0) hsh = (hsh + 1) & 1023; ck[hsh] = pal[i]; cv[hsh] = (short)i; }
    }
    for (int ty = 0; ty < t->nty; ty++) for (int tx = 0; tx < t->ntx; tx++) {
        Tile *k = &t->tiles[ty * t->ntx + tx];
        k->x0 = tx * TILE_MAX; k->y0 = ty * TILE_MAX;
        k->w = (w - k->x0 < TILE_MAX) ? w - k->x0 : TILE_MAX;
        k->h = (h - k->y0 < TILE_MAX) ? h - k->y0 : TILE_MAX;
        k->fmt = fmt; k->clut = t->clut;
        k->pw = pow2ge(k->w); k->ph = pow2ge(k->h);
        if (fmt == 1 && k->pw < 16) k->pw = 16;     /* texture rows must be 16-byte aligned */
        if (fmt == 2 && k->pw < 32) k->pw = 32;
        size_t bytes = fmt == 0 ? (size_t)k->pw * k->ph * 4 : fmt == 1 ? (size_t)k->pw * k->ph : (size_t)k->pw * k->ph / 2;
        k->px = memalign(16, bytes);
        if (!k->px) { stbi_image_free(img); tex_free(t); lua_pushnil(L); lua_pushstring(L, "out of memory"); return 2; }
        memset(k->px, 0, bytes);
        t->bytes += bytes;
        if (fmt == 0) {
            for (int y = 0; y < k->h; y++)
                memcpy(k->px + (size_t)y * k->pw, (uint32_t *)img + (size_t)(k->y0 + y) * w + k->x0, (size_t)k->w * 4);
        } else {
            unsigned char *dst = (unsigned char *)k->px;
            for (int y = 0; y < k->h; y++) {
                const uint32_t *src = (uint32_t *)img + (size_t)(k->y0 + y) * w + k->x0;
                for (int x = 0; x < k->w; x++) {
                    uint32_t c = src[x]; if ((c >> 24) == 0) c = 0;
                    unsigned hsh = (c * 2654435761u) >> 22;
                    while (ck[hsh] != c) hsh = (hsh + 1) & 1023;
                    int idx = cv[hsh];
                    if (fmt == 1) dst[(size_t)y * k->pw + x] = (unsigned char)idx;
                    else { unsigned char *b = &dst[(size_t)y * (k->pw / 2) + x / 2]; *b |= (x & 1) ? (idx << 4) : idx; }
                }
            }
        }
        sceKernelDcacheWritebackRange(k->px, bytes);
    }
    tex_bytes_total += t->bytes;
    stbi_image_free(img);
    lua_pushinteger(L, w); lua_pushinteger(L, h);
    return 3;
}
static int l_tex_filter(lua_State *L) {
    Tex *t = luaL_checkudata(L, 1, "balatro.tex"); t->linear = lua_toboolean(L, 2); return 0;
}

/* ------------------------------------------------------------------ drawing */
typedef struct { float u, v; unsigned int color; float x, y, z; } VertT;
typedef struct { unsigned int color; float x, y, z; } VertC;

static int bound_linear = -1;
static int tex_mode_on = 0;

static unsigned pack_color(lua_State *L, int i) {
    float r = luaL_checknumber(L, i), g = luaL_checknumber(L, i + 1), b = luaL_checknumber(L, i + 2), a = luaL_optnumber(L, i + 3, 1);
    #define C8(v) ((unsigned)((v) < 0 ? 0 : (v) > 1 ? 255 : (v) * 255.0f + 0.5f))
    return (C8(a) << 24) | (C8(b) << 16) | (C8(g) << 8) | C8(r);
}
static void bind_tile(const Tile *k, int linear) {
    if (!tex_mode_on) { sceGuEnable(GU_TEXTURE_2D); tex_mode_on = 1; }
    if (bound_px != k->px) {
        if (k->fmt) {
            if (bound_clut != k->clut) { sceGuClutMode(GU_PSM_8888, 0, 0xFF, 0); sceGuClutLoad(k->fmt == 1 ? 32 : 2, k->clut); bound_clut = k->clut; }
            sceGuTexMode(k->fmt == 1 ? GU_PSM_T8 : GU_PSM_T4, 0, 0, 0);
        } else sceGuTexMode(GU_PSM_8888, 0, 0, 0);
        sceGuTexImage(0, k->pw, k->ph, k->pw, k->px);
        sceGuTexFlush();
        bound_px = k->px;
    }
    if (bound_linear != linear) {
        sceGuTexFilter(linear ? GU_LINEAR : GU_NEAREST, linear ? GU_LINEAR : GU_NEAREST);
        bound_linear = linear;
    }
}
/* ---- draw batching: consecutive quads/polygons with the same texture (or untextured) go out as one
   GU_TRIANGLES draw. Vertices are written straight into display-list memory (sceGuGetMemory). Order is kept:
   any change of kind/texture/filter, scissor, blend, clear or frame end flushes first. */
#define BATCH_CHUNK 1536
static VertT *bt = NULL; static int nbt = 0, bt_cap = 0;    /* textured: draw start, count, free verts from start */
static VertC *bc = NULL; static int nbc = 0, bc_cap = 0;    /* untextured */
static Tile bt_tile; static int bt_linear = -1;
static void poly_begin(void) { if (tex_mode_on) { sceGuDisable(GU_TEXTURE_2D); tex_mode_on = 0; } }
static void flush_batch(void) {
    if (nbt) {
        bind_tile(&bt_tile, bt_linear);
        sceGuDrawArray(GU_TRIANGLES, GU_TEXTURE_32BITF | GU_COLOR_8888 | GU_VERTEX_32BITF | GU_TRANSFORM_2D, nbt, 0, bt);
        bt += nbt; bt_cap -= nbt; nbt = 0;
    }
    if (nbc) {
        poly_begin();
        sceGuDrawArray(GU_TRIANGLES, GU_COLOR_8888 | GU_VERTEX_32BITF | GU_TRANSFORM_2D, nbc, 0, bc);
        bc += nbc; bc_cap -= nbc; nbc = 0;
    }
}
static void batch_reset(void) { bt = NULL; nbt = bt_cap = 0; bc = NULL; nbc = bc_cap = 0; }
/* returns space for n textured vertices of tile k; the caller fills them and then does nbt += n */
static VertT *tex_reserve(const Tile *k, int linear, int n) {
    if (nbc) flush_batch();
    if (nbt && (bt_tile.px != k->px || bt_linear != linear)) flush_batch();
    if (nbt + n > bt_cap) {
        flush_batch();
        int cap = n > BATCH_CHUNK ? n : BATCH_CHUNK;
        bt = sceGuGetMemory(cap * sizeof(VertT)); bt_cap = cap;
    }
    bt_tile = *k; bt_linear = linear;
    return bt + nbt;
}
static VertC *col_reserve(int n) {
    if (nbt) flush_batch();
    if (nbc + n > bc_cap) {
        flush_batch();
        int cap = n > BATCH_CHUNK ? n : BATCH_CHUNK;
        bc = sceGuGetMemory(cap * sizeof(VertC)); bc_cap = cap;
    }
    return bc + nbc;
}
/* quad of tile region [ix0,ix1)x[iy0,iy1) in tile-pixel coords; local coords lx,ly offset from region origin. */
static void emit_quad(const Tile *k, int linear, float ix0, float iy0, float ix1, float iy1,
                      float lx0, float ly0, float lx1, float ly1, const float *m, unsigned col) {
    VertT *v = tex_reserve(k, linear, 6);
    /* GU_TRANSFORM_2D (through mode): UVs are in texels, not normalized */
    float xs[4] = {lx0, lx1, lx0, lx1}, ys[4] = {ly0, ly0, ly1, ly1};
    float us[4] = {ix0, ix1, ix0, ix1}, vs[4] = {iy0, iy0, iy1, iy1};
    VertT q[4];
    for (int i = 0; i < 4; i++) {
        q[i].u = us[i]; q[i].v = vs[i]; q[i].color = col;
        q[i].x = m[0] * xs[i] + m[2] * ys[i] + m[4];
        q[i].y = m[1] * xs[i] + m[3] * ys[i] + m[5];
        q[i].z = 0;
    }
    v[0] = q[0]; v[1] = q[1]; v[2] = q[2]; v[3] = q[1]; v[4] = q[3]; v[5] = q[2];
    nbt += 6;
}
static void getm(lua_State *L, int i, float *m) { for (int k = 0; k < 6; k++) m[k] = (float)luaL_checknumber(L, i + k); }

/* ---------------------------------------------------------- graphics state (matrix stack, colour) */
static float M[6] = {1, 0, 0, 1, 0, 0};
static float stk[64][6]; static int sp = 0;
static float cur_r = 1, cur_g = 1, cur_b = 1, cur_a = 1;

static unsigned pack4(float r, float g, float b, float a) {
    #define C8X(v) ((unsigned)((v) < 0 ? 0 : (v) > 1 ? 255 : (v) * 255.0f + 0.5f))
    return (C8X(a) << 24) | (C8X(b) << 16) | (C8X(g) << 8) | C8X(r);
}
/* setColor(r,g,b[,a]) or setColor({r,g,b[,a]}) (one C call, no Lua-side table traffic) */
static int l_set_color(lua_State *L) {
    if (lua_istable(L, 1)) {
        lua_rawgeti(L, 1, 1); lua_rawgeti(L, 1, 2); lua_rawgeti(L, 1, 3); lua_rawgeti(L, 1, 4);
        cur_r = luaL_checknumber(L, -4); cur_g = luaL_checknumber(L, -3); cur_b = luaL_checknumber(L, -2);
        cur_a = lua_isnil(L, -1) ? 1.0f : (float)luaL_checknumber(L, -1);
        return 0;
    }
    cur_r = luaL_checknumber(L, 1); cur_g = luaL_checknumber(L, 2); cur_b = luaL_checknumber(L, 3); cur_a = luaL_optnumber(L, 4, 1);
    return 0;
}
static int l_get_color(lua_State *L) {
    lua_pushnumber(L, cur_r); lua_pushnumber(L, cur_g); lua_pushnumber(L, cur_b); lua_pushnumber(L, cur_a);
    return 4;
}
static int l_push(lua_State *L) { (void)L; if (sp < 64) memcpy(stk[sp++], M, sizeof M); return 0; }
static int l_pop(lua_State *L) { (void)L; if (sp > 0) memcpy(M, stk[--sp], sizeof M); return 0; }
static int l_stack_depth(lua_State *L) { lua_pushinteger(L, sp); return 1; }
static int l_origin(lua_State *L) { (void)L; M[0] = 1; M[1] = 0; M[2] = 0; M[3] = 1; M[4] = 0; M[5] = 0; return 0; }
static int l_reset_stack(lua_State *L) { sp = 0; return l_origin(L); }
static int l_translate(lua_State *L) {
    float tx = luaL_checknumber(L, 1), ty = luaL_checknumber(L, 2);
    M[4] += M[0] * tx + M[2] * ty; M[5] += M[1] * tx + M[3] * ty; return 0;
}
static int l_scale(lua_State *L) {
    float sx = luaL_checknumber(L, 1), sy = luaL_optnumber(L, 2, sx);
    M[0] *= sx; M[1] *= sx; M[2] *= sy; M[3] *= sy; return 0;
}
static int l_rotate(lua_State *L) {
    float r = luaL_checknumber(L, 1), c = vfpu_cosf(r), s = vfpu_sinf(r);
    float a = M[0], b = M[1], cc = M[2], d = M[3];
    M[0] = a * c + cc * s; M[1] = b * c + d * s; M[2] = -a * s + cc * c; M[3] = -b * s + d * c; return 0;
}
/* shear(kx, ky): M = M * [1 kx; ky 1], LOVE's love.graphics.shear. */
static int l_shear(lua_State *L) {
    float kx = luaL_optnumber(L, 1, 0), ky = luaL_optnumber(L, 2, 0);
    float a = M[0], b = M[1], c = M[2], d = M[3];
    M[0] = a + c * ky; M[1] = b + d * ky; M[2] = a * kx + c; M[3] = b * kx + d; return 0;
}
/* get_matrix() -> a, b, c, d, e, f: a point (x, y) maps to (a*x + c*y + e, b*x + d*y + f). */
static int l_get_matrix(lua_State *L) {
    for (int k = 0; k < 6; k++) lua_pushnumber(L, M[k]);
    return 6;
}
/* set_matrix(a, b, c, d, e, f): replaces the top matrix (love.graphics.replaceTransform). */
static int l_set_matrix(lua_State *L) { getm(L, 1, M); return 0; }
/* mul_matrix(a, b, c, d, e, f): M = M * T (love.graphics.applyTransform). */
static int l_mul_matrix(lua_State *L) {
    float t[6]; getm(L, 1, t);
    float a = M[0], b = M[1], c = M[2], d = M[3];
    float e = M[0] * t[4] + M[2] * t[5] + M[4], f = M[1] * t[4] + M[3] * t[5] + M[5];
    M[0] = a * t[0] + c * t[1]; M[1] = b * t[0] + d * t[1];
    M[2] = a * t[2] + c * t[3]; M[3] = b * t[2] + d * t[3];
    M[4] = e; M[5] = f; return 0;
}
/* native.prep_draw(S, tx, ty, r, ox, oy, sc): push; scale(S); translate(tx,ty); rotate(r) if r~=0; translate(ox,oy); scale(sc).
   Balatro's prep_draw in one call. */
static int l_prep_draw(lua_State *L) {
    float S = (float)lua_tonumber(L, 1), tx = (float)lua_tonumber(L, 2), ty = (float)lua_tonumber(L, 3), r = (float)lua_tonumber(L, 4);
    float ox = (float)lua_tonumber(L, 5), oy = (float)lua_tonumber(L, 6), sc = (float)lua_tonumber(L, 7);
    if (sp < 64) memcpy(stk[sp++], M, sizeof M);
    M[0] *= S; M[1] *= S; M[2] *= S; M[3] *= S;
    M[4] += M[0] * tx + M[2] * ty; M[5] += M[1] * tx + M[3] * ty;
    if (r != 0) {
        float c = vfpu_cosf(r), s = vfpu_sinf(r), a = M[0], b = M[1], cc = M[2], d = M[3];
        M[0] = a * c + cc * s; M[1] = b * c + d * s; M[2] = -a * s + cc * c; M[3] = -b * s + d * c;
    }
    M[4] += M[0] * ox + M[2] * oy; M[5] += M[1] * ox + M[3] * oy;
    M[0] *= sc; M[1] *= sc; M[2] *= sc; M[3] *= sc;
    return 0;
}
/* o = M * T(x,y) R(r) S(sx,sy) T(-ox,-oy) */
static void compose(float x, float y, float r, float sx, float sy, float ox, float oy, float *o) {
    float la, lb, lc, ld;
    if (r != 0) { float c = vfpu_cosf(r), s = vfpu_sinf(r); la = c * sx; lb = s * sx; lc = -s * sy; ld = c * sy; }
    else { la = sx; lb = 0; lc = 0; ld = sy; }
    float le = x - (la * ox + lc * oy), lf = y - (lb * ox + ld * oy);
    o[0] = M[0] * la + M[2] * lb; o[1] = M[1] * la + M[3] * lb;
    o[2] = M[0] * lc + M[2] * ld; o[3] = M[1] * lc + M[3] * ld;
    o[4] = M[0] * le + M[2] * lf + M[4]; o[5] = M[1] * le + M[3] * lf + M[5];
}
static void compose_args(lua_State *L, int i, float *o) {
    float x = luaL_optnumber(L, i, 0), y = luaL_optnumber(L, i + 1, 0), r = luaL_optnumber(L, i + 2, 0);
    float sx = luaL_optnumber(L, i + 3, 1), sy = luaL_optnumber(L, i + 4, sx);
    float ox = luaL_optnumber(L, i + 5, 0), oy = luaL_optnumber(L, i + 6, 0);
    compose(x, y, r, sx, sy, ox, oy, o);
}

/* native.draw(tex, qx,qy,qw,qh, [x,y,r,sx,sy,ox,oy]) with current matrix+colour */
static int l_draw(lua_State *L) {
    if (suppress_draw) return 0;
    Tex *t = luaL_checkudata(L, 1, "balatro.tex");
    float sx = luaL_checknumber(L, 2), sy = luaL_checknumber(L, 3), sw = luaL_checknumber(L, 4), sh = luaL_checknumber(L, 5);
    float m[6]; compose_args(L, 6, m);
    unsigned col = pack4(cur_r, cur_g, cur_b, cur_a);
    if (!t->tiles) return 0;
    for (int ty = 0; ty < t->nty; ty++) for (int tx = 0; tx < t->ntx; tx++) {
        const Tile *k = &t->tiles[ty * t->ntx + tx];
        float ix0 = fmaxf(sx, k->x0), iy0 = fmaxf(sy, k->y0);
        float ix1 = fminf(sx + sw, k->x0 + k->w), iy1 = fminf(sy + sh, k->y0 + k->h);
        if (ix1 <= ix0 || iy1 <= iy0) continue;
        emit_quad(k, t->linear, ix0 - k->x0, iy0 - k->y0, ix1 - k->x0, iy1 - k->y0,
                  ix0 - sx, iy0 - sy, ix1 - sx, iy1 - sy, m, col);
    }
    return 0;
}

/* native.fill_poly(points): convex polygon, points = flat {x1,y1,...} in local coords */
static int l_fill_poly(lua_State *L) {
    if (suppress_draw) return 0;
    luaL_checktype(L, 1, LUA_TTABLE);
    unsigned col = pack4(cur_r, cur_g, cur_b, cur_a);
    int n = (int)lua_objlen(L, 1) / 2;
    if (n < 3) return 0;
    VertC *v = col_reserve((n - 2) * 3);
    VertC first, prev, cur;
    for (int i = 0; i < n; i++) {
        lua_rawgeti(L, 1, 2 * i + 1); lua_rawgeti(L, 1, 2 * i + 2);
        float x = lua_tonumber(L, -2), y = lua_tonumber(L, -1); lua_pop(L, 2);
        cur.x = M[0] * x + M[2] * y + M[4]; cur.y = M[1] * x + M[3] * y + M[5]; cur.z = 0; cur.color = col;
        if (i == 0) first = cur;
        else if (i >= 2) { *v++ = first; *v++ = prev; *v++ = cur; }
        prev = cur;
    }
    nbc += (n - 2) * 3;
    return 0;
}
static void quad4(const float *px, const float *py) {
    if (suppress_draw) return;
    unsigned col = pack4(cur_r, cur_g, cur_b, cur_a);
    VertC *v = col_reserve(6), q[4];
    for (int i = 0; i < 4; i++) {
        q[i].x = M[0] * px[i] + M[2] * py[i] + M[4]; q[i].y = M[1] * px[i] + M[3] * py[i] + M[5]; q[i].z = 0; q[i].color = col;
    }
    v[0] = q[0]; v[1] = q[1]; v[2] = q[2]; v[3] = q[0]; v[4] = q[2]; v[5] = q[3];
    nbc += 6;
}
static int l_fill_rect(lua_State *L) {
    float x = luaL_checknumber(L, 1), y = luaL_checknumber(L, 2), w = luaL_checknumber(L, 3), h = luaL_checknumber(L, 4);
    float px[4] = {x, x + w, x + w, x}, py[4] = {y, y, y + h, y + h};
    quad4(px, py); return 0;
}
static int l_line(lua_State *L) {
    float x1 = luaL_checknumber(L, 1), y1 = luaL_checknumber(L, 2), x2 = luaL_checknumber(L, 3), y2 = luaL_checknumber(L, 4), lw = luaL_checknumber(L, 5);
    float dx = x2 - x1, dy = y2 - y1, len = sqrtf(dx * dx + dy * dy);
    if (len == 0) return 0;
    float nx = -dy / len * lw / 2, ny = dx / len * lw / 2;
    float px[4] = {x1 + nx, x2 + nx, x2 - nx, x1 - nx}, py[4] = {y1 + ny, y2 + ny, y2 - ny, y1 - ny};
    quad4(px, py); return 0;
}

static int frame_no = 0;
static void trace(const char *what) {
    if (frame_no < 0 || frame_no > -1) return; /* tracing disabled; set a frame window to enable */
    FILE *f = fopen("native_trace.txt", frame_no == 591 && what[0] == 'b' ? "w" : "a");
    if (!f) return;
    fprintf(f, "%d %s %llu\n", frame_no, what, (unsigned long long)sceKernelGetSystemTimeWide());
    fclose(f);
}
static int l_begin(lua_State *L) {
    (void)L;
    trace("begin");
    sceGuStart(GU_DIRECT, gu_list);
    batch_reset();
    cur_target = NULL; suppress_draw = 0;
    bound_px = NULL; bound_clut = NULL; bound_linear = -1; tex_mode_on = 0;
    sceGuDisable(GU_TEXTURE_2D);   /* the GPU keeps the enable bit across frames: make it match tex_mode_on */
    sceGuScissor(0, 0, SCR_W, SCR_H);
    return 0;
}
/* native.canvas_new(w,h) -> tex | nil (no VRAM). RGBA8888, stride 512, usable as a texture with native.draw. */
static int l_canvas_new(lua_State *L) {
    int w = (int)luaL_checknumber(L, 1), h = (int)luaL_checknumber(L, 2);
    if (w < 1 || h < 1 || w > CANVAS_STRIDE || h > 512) { lua_pushnil(L); lua_pushstring(L, "canvas size must be 1..512"); return 2; }
    int ph = pow2ge(h);
    unsigned off = vram_alloc((unsigned)CANVAS_STRIDE * ph * 4);
    if (!off) { lua_pushnil(L); lua_pushstring(L, "out of VRAM"); return 2; }
    Tex *t = lua_newuserdata(L, sizeof(Tex)); memset(t, 0, sizeof *t);
    luaL_getmetatable(L, "balatro.tex"); lua_setmetatable(L, -2);
    t->w = w; t->h = h; t->ntx = t->nty = 1; t->linear = 0; t->vram_off = off;
    t->tiles = calloc(1, sizeof(Tile));
    Tile *k = &t->tiles[0];
    k->w = w; k->h = h; k->pw = CANVAS_STRIDE; k->ph = ph; k->px = (uint32_t *)(VRAM_BASE + off);
    return 1;
}
static void target_scissor(void) {
    if (cur_target) sceGuScissor(0, 0, cur_target->w, cur_target->h); else sceGuScissor(0, 0, SCR_W, SCR_H);
}
/* native.canvas_set(tex|nil): redirect drawing to a canvas, or back to the screen */
static int l_canvas_set(lua_State *L) {
    flush_batch();
    Tex *t = lua_isnoneornil(L, 1) ? NULL : (Tex *)luaL_checkudata(L, 1, "balatro.tex");
    if (t && !t->vram_off) t = NULL;
    cur_target = t;
    if (t) sceGuDrawBufferList(GU_PSM_8888, (void *)(uintptr_t)t->vram_off, CANVAS_STRIDE);
    else sceGuDrawBufferList(GU_PSM_8888, (void *)(uintptr_t)screen_draw_off, 512);
    target_scissor();
    bound_px = NULL;                      /* the canvas just rendered must be re-flushed in the texture cache */
    return 0;
}
/* native.canvas_pixel(tex, x, y) -> r,g,b,a (0..255): CPU read of canvas VRAM (uncached mirror). Only valid after the
   frame's GE work finished, i.e. after end_frame (love.graphics.present). Debug / ImageData:getPixel. */
static int l_canvas_pixel(lua_State *L) {
    Tex *t = (Tex *)luaL_checkudata(L, 1, "balatro.tex");
    int x = (int)luaL_checknumber(L, 2), y = (int)luaL_checknumber(L, 3);
    if (!t->vram_off || x < 0 || y < 0 || x >= t->w || y >= t->h) return 0;
    uint32_t c = *(volatile uint32_t *)(0x44000000u + t->vram_off + ((unsigned)y * CANVAS_STRIDE + x) * 4);
    lua_pushinteger(L, c & 255); lua_pushinteger(L, c >> 8 & 255); lua_pushinteger(L, c >> 16 & 255); lua_pushinteger(L, c >> 24);
    return 4;
}
static int l_suppress(lua_State *L) { flush_batch(); suppress_draw = lua_toboolean(L, 1); return 0; }

static int l_clear(lua_State *L) { trace("clear");
    flush_batch();
    if (cur_target) {   /* sceGuClear always clears 480x272: overwrite the canvas with a no-blend rect instead */
        unsigned col = pack_color(L, 1);
        VertC *v = sceGuGetMemory(4 * sizeof(VertC));
        float w = (float)cur_target->w, h = (float)cur_target->h;
        float xs[4] = {0, w, w, 0}, ys[4] = {0, 0, h, h};
        for (int i = 0; i < 4; i++) { v[i].x = xs[i]; v[i].y = ys[i]; v[i].z = 0; v[i].color = col; }
        poly_begin(); sceGuDisable(GU_BLEND);
        sceGuStencilFunc(GU_ALWAYS, col >> 24, 0xFF);          /* stencil/alpha := requested alpha */
        sceGuDrawArray(GU_TRIANGLE_FAN, GU_COLOR_8888 | GU_VERTEX_32BITF | GU_TRANSFORM_2D, 4, 0, v);
        sceGuStencilFunc(GU_ALWAYS, 0xFF, 0xFF);
        sceGuEnable(GU_BLEND);
        return 0;
    }
    sceGuClearColor(pack_color(L, 1));
    sceGuClear(GU_COLOR_BUFFER_BIT);
    return 0;
}
static int l_end(lua_State *L) {
    trace("finish");
    flush_batch();
    if (cur_target) { cur_target = NULL; sceGuDrawBufferList(GU_PSM_8888, (void *)(uintptr_t)screen_draw_off, 512); target_scissor(); }
    sceGuFinish(); trace("sync");
    sceGuSync(0, 0);
    trace("vblank");
    /* Wait for vblank only when the frame was shorter than one: the previous swap is then still
       pending. A longer frame has already passed a vblank, so waiting again only adds ~8 ms. */
    static unsigned long long last_swap = 0;
    if (lua_toboolean(L, 1) && sceKernelGetSystemTimeWide() - last_swap < 16700) sceDisplayWaitVblankStart();
    trace("swap");
    sceGuSwapBuffers();
    screen_draw_off = screen_draw_off ? 0 : 0x88000;
    last_swap = sceKernelGetSystemTimeWide();
    frame_no++;
    return 0;
}
static int l_scissor(lua_State *L) { trace("scissor");
    flush_batch();
    if (lua_isnoneornil(L, 1)) { target_scissor(); return 0; }
    int x = (int)luaL_checknumber(L, 1), y = (int)luaL_checknumber(L, 2), w = (int)luaL_checknumber(L, 3), h = (int)luaL_checknumber(L, 4);
    if (x < 0) { w += x; x = 0; } if (y < 0) { h += y; y = 0; }
    if (w < 0) w = 0; if (h < 0) h = 0;
    sceGuScissor(x, y, w, h);
    return 0;
}
static int l_blend(lua_State *L) { trace("blend");
    flush_batch();
    int m = (int)luaL_checkinteger(L, 1);
    if (m == 1) sceGuBlendFunc(GU_ADD, GU_SRC_ALPHA, GU_FIX, 0, 0xFFFFFFFF);
    else if (m == 2) sceGuBlendFunc(GU_ADD, GU_DST_COLOR, GU_FIX, 0, 0);
    else sceGuBlendFunc(GU_ADD, GU_SRC_ALPHA, GU_ONE_MINUS_SRC_ALPHA, 0, 0);
    return 0;
}

/* -------------------------------------------------------------------- fonts */
#define GLYPH_HASH 4096
typedef struct { int cp; int has; float xoff, yoff, w, h, adv; int page; float u0, v0, u1, v1; } Glyph;
typedef struct { Tile tile; int cx, cy, rowh; } Page;
typedef struct {
    unsigned char *data; stbtt_fontinfo info;
    float lscale, rscale, ratio, ascent, descent, lineh;
    Page *pages; int npages; Glyph *glyphs;
} Font;

static int font_gc(lua_State *L) {
    Font *f = luaL_checkudata(L, 1, "balatro.font");
    for (int i = 0; i < f->npages; i++) free(f->pages[i].tile.px);
    free(f->pages); free(f->glyphs); free(f->data); f->pages = NULL; f->glyphs = NULL; f->data = NULL;
    return 0;
}
static int l_font_load(lua_State *L) { trace("fontload");
    const char *path = luaL_checkstring(L, 1);
    float size = luaL_checknumber(L, 2), rsize = luaL_optnumber(L, 3, size);
    FILE *fp = fopen(path, "rb");
    if (!fp) { lua_pushnil(L); lua_pushfstring(L, "cannot open %s", path); return 2; }
    fseek(fp, 0, SEEK_END); long len = ftell(fp); fseek(fp, 0, SEEK_SET);
    Font *f = lua_newuserdata(L, sizeof(Font)); memset(f, 0, sizeof *f);
    luaL_getmetatable(L, "balatro.font"); lua_setmetatable(L, -2);
    f->data = malloc(len);
    if (!f->data || fread(f->data, 1, len, fp) != (size_t)len) { fclose(fp); lua_pushnil(L); lua_pushstring(L, "read error"); return 2; }
    fclose(fp);
    if (!stbtt_InitFont(&f->info, f->data, stbtt_GetFontOffsetForIndex(f->data, 0))) { lua_pushnil(L); lua_pushstring(L, "bad font"); return 2; }
    f->lscale = stbtt_ScaleForPixelHeight(&f->info, size);
    f->rscale = stbtt_ScaleForPixelHeight(&f->info, rsize);
    f->ratio = f->lscale / f->rscale;
    int a, d, g; stbtt_GetFontVMetrics(&f->info, &a, &d, &g);
    f->ascent = a * f->lscale; f->descent = d * f->lscale; f->lineh = (a - d + g) * f->lscale;
    f->glyphs = calloc(GLYPH_HASH, sizeof(Glyph));
    lua_pushnumber(L, f->ascent); lua_pushnumber(L, f->descent); lua_pushnumber(L, f->lineh);
    return 4;
}
static Page *font_new_page(Font *f) {
    f->pages = realloc(f->pages, (f->npages + 1) * sizeof(Page));
    Page *p = &f->pages[f->npages++]; memset(p, 0, sizeof *p);
    p->tile.pw = p->tile.ph = TILE_MAX; p->tile.w = p->tile.h = TILE_MAX;
    p->tile.px = memalign(16, TILE_MAX * TILE_MAX * 4);
    memset(p->tile.px, 0, TILE_MAX * TILE_MAX * 4);
    p->cx = p->cy = 1; p->rowh = 0;
    return p;
}
static Glyph *font_glyph(Font *f, int cp) {
    unsigned h = ((unsigned)cp * 2654435761u) % GLYPH_HASH;
    for (int probe = 0; probe < GLYPH_HASH; probe++, h = (h + 1) % GLYPH_HASH) {
        Glyph *g = &f->glyphs[h];
        if (g->has && g->cp == cp) return g;
        if (!g->has) {
            g->has = 1; g->cp = cp;
            int adv, lsb; stbtt_GetCodepointHMetrics(&f->info, cp, &adv, &lsb);
            g->adv = adv * f->lscale;
            int x0, y0, x1, y1; stbtt_GetCodepointBitmapBox(&f->info, cp, f->rscale, f->rscale, &x0, &y0, &x1, &y1);
            int bw = x1 - x0, bh = y1 - y0;
            g->page = -1;
            if (bw > 0 && bh > 0 && bw + 2 <= TILE_MAX && bh + 2 <= TILE_MAX) {
                Page *p = f->npages ? &f->pages[f->npages - 1] : font_new_page(f);
                if (p->cx + bw + 1 > TILE_MAX) { p->cx = 1; p->cy += p->rowh + 1; p->rowh = 0; }
                if (p->cy + bh + 1 > TILE_MAX) { p = font_new_page(f); }
                unsigned char *bm = malloc(bw * bh);
                stbtt_MakeCodepointBitmap(&f->info, bm, bw, bh, bw, f->rscale, f->rscale, cp);
                for (int y = 0; y < bh; y++) for (int x = 0; x < bw; x++)
                    p->tile.px[(p->cy + y) * TILE_MAX + p->cx + x] = ((uint32_t)bm[y * bw + x] << 24) | 0x00FFFFFF;
                free(bm);
                sceKernelDcacheWritebackRange(p->tile.px, TILE_MAX * TILE_MAX * 4);
                g->page = f->npages - 1;
                g->u0 = (float)p->cx; g->v0 = (float)p->cy; g->u1 = (float)(p->cx + bw); g->v1 = (float)(p->cy + bh);
                g->xoff = x0 * f->ratio; g->yoff = y0 * f->ratio; g->w = bw * f->ratio; g->h = bh * f->ratio;
                p->cx += bw + 1; if (bh > p->rowh) p->rowh = bh;
            }
            return g;
        }
    }
    return NULL;
}
static int utf8_next(const unsigned char **s) {
    const unsigned char *p = *s; int c = *p++;
    if (c < 0x80) { *s = p; return c; }
    int n = (c >= 0xF0) ? 3 : (c >= 0xE0) ? 2 : 1; int cp = c & (0x3F >> n);
    while (n-- && (*p & 0xC0) == 0x80) cp = (cp << 6) | (*p++ & 0x3F);
    *s = p; return cp;
}
static float kern_adv(Font *f, int a, int b) { return b ? stbtt_GetCodepointKernAdvance(&f->info, a, b) * f->lscale : 0; }

static int l_font_width(lua_State *L) { trace("fwidth");
    Font *f = luaL_checkudata(L, 1, "balatro.font");
    const unsigned char *s = (const unsigned char *)luaL_checkstring(L, 2);
    float w = 0, best = 0; int prev = 0;
    while (*s) {
        int cp = utf8_next(&s);
        if (cp == '\n') { if (w > best) best = w; w = 0; prev = 0; continue; }
        Glyph *g = font_glyph(f, cp); if (!g) continue;
        w += g->adv + kern_adv(f, prev, cp); prev = cp;
    }
    lua_pushnumber(L, w > best ? w : best);
    return 1;
}
static int l_font_has(lua_State *L) {
    Font *f = luaL_checkudata(L, 1, "balatro.font");
    const unsigned char *s = (const unsigned char *)luaL_checkstring(L, 2);
    while (*s) { int cp = utf8_next(&s); if (!stbtt_FindGlyphIndex(&f->info, cp)) { lua_pushboolean(L, 0); return 1; } }
    lua_pushboolean(L, 1); return 1;
}
/* native.font_draw(font, str, x,y,r,sx,sy,ox,oy, lx,ly, [cr,cg,cb,ca]) ; origin = top-left of the text line.
   lx,ly offset the pen in local space; cr..ca multiply the current colour (coloured text). */
static int l_font_draw(lua_State *L) {
    if (suppress_draw) return 0;
    trace("fdraw");
    Font *f = luaL_checkudata(L, 1, "balatro.font");
    const unsigned char *s = (const unsigned char *)luaL_checkstring(L, 2);
    float m[6]; compose_args(L, 3, m);
    float lx = luaL_optnumber(L, 10, 0), ly = luaL_optnumber(L, 11, 0);
    m[4] += m[0] * lx + m[2] * ly; m[5] += m[1] * lx + m[3] * ly;
    unsigned col = pack4(cur_r * luaL_optnumber(L, 12, 1), cur_g * luaL_optnumber(L, 13, 1), cur_b * luaL_optnumber(L, 14, 1), cur_a * luaL_optnumber(L, 15, 1));
    float pen = 0, base = f->ascent; int prev = 0;
    while (*s) {
        int cp = utf8_next(&s);
        if (cp == '\n') { pen = 0; base += f->lineh; prev = 0; continue; }
        Glyph *g = font_glyph(f, cp); if (!g) continue;
        pen += kern_adv(f, prev, cp); prev = cp;
        if (g->page >= 0) {
            VertT *v = tex_reserve(&f->pages[g->page].tile, 1, 6);
            float x0 = pen + g->xoff, y0 = base + g->yoff, x1 = x0 + g->w, y1 = y0 + g->h;
            float xs[4] = {x0, x1, x0, x1}, ys[4] = {y0, y0, y1, y1};
            float us[4] = {g->u0, g->u1, g->u0, g->u1}, vs[4] = {g->v0, g->v0, g->v1, g->v1};
            VertT q[4];
            for (int i = 0; i < 4; i++) {
                q[i].u = us[i]; q[i].v = vs[i]; q[i].color = col; q[i].z = 0;
                q[i].x = m[0] * xs[i] + m[2] * ys[i] + m[4];
                q[i].y = m[1] * xs[i] + m[3] * ys[i] + m[5];
            }
            v[0] = q[0]; v[1] = q[1]; v[2] = q[2]; v[3] = q[1]; v[4] = q[3]; v[5] = q[2];
            nbt += 6;
        }
        pen += g->adv;
    }
    return 0;
}

/* base64 / hex (LÖVE love.data.encode/decode); done in C: Lua gsub-based codecs need ~8x the input in garbage */
static const char B64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static int l_b64encode(lua_State *L) {
    size_t n; const unsigned char *s = (const unsigned char *)luaL_checklstring(L, 1, &n);
    size_t on = (n + 2) / 3 * 4; char *o = malloc(on + 1); if (!o) return luaL_error(L, "not enough memory");
    size_t j = 0;
    for (size_t i = 0; i < n; i += 3) {
        unsigned v = s[i] << 16 | (i + 1 < n ? s[i + 1] << 8 : 0) | (i + 2 < n ? s[i + 2] : 0);
        o[j++] = B64[v >> 18 & 63]; o[j++] = B64[v >> 12 & 63];
        o[j++] = i + 1 < n ? B64[v >> 6 & 63] : '='; o[j++] = i + 2 < n ? B64[v & 63] : '=';
    }
    lua_pushlstring(L, o, on); free(o); return 1;
}
static int l_b64decode(lua_State *L) {
    size_t n; const unsigned char *s = (const unsigned char *)luaL_checklstring(L, 1, &n);
    unsigned char map[256]; memset(map, 255, sizeof map);
    for (int i = 0; i < 64; i++) map[(unsigned char)B64[i]] = (unsigned char)i;
    unsigned char *o = malloc(n / 4 * 3 + 3); if (!o) return luaL_error(L, "not enough memory");
    size_t j = 0; unsigned acc = 0; int bits = 0;
    for (size_t i = 0; i < n; i++) {
        unsigned char m = map[s[i]]; if (m == 255) continue;   /* skips '=', whitespace, junk */
        acc = acc << 6 | m; bits += 6;
        if (bits >= 8) { bits -= 8; o[j++] = (unsigned char)(acc >> bits); acc &= (1u << bits) - 1; }
    }
    lua_pushlstring(L, (const char *)o, j); free(o); return 1;
}

/* -------------------------------------------------------------------- system */
static int l_pad(lua_State *L) { trace("pad");
    SceCtrlData pad; sceCtrlPeekBufferPositive(&pad, 1);
    lua_pushinteger(L, pad.Buttons);
    lua_pushnumber(L, (pad.Lx - 128) / 128.0); lua_pushnumber(L, (pad.Ly - 128) / 128.0);
    return 3;
}
static int l_time(lua_State *L) { lua_pushnumber(L, sceKernelGetSystemTimeWide() / 1000000.0); return 1; }
static int l_sleep(lua_State *L) { trace("sleep"); double s = luaL_checknumber(L, 1); if (s > 0) sceKernelDelayThread((SceUInt)(s * 1e6)); return 0; }
static int l_palette(lua_State *L) { use_palette = lua_toboolean(L, 1); return 0; }
static int l_texmem(lua_State *L) { lua_pushinteger(L, (lua_Integer)tex_bytes_total); return 1; }
static int l_mem(lua_State *L) { lua_pushinteger(L, sceKernelTotalFreeMemSize()); lua_pushinteger(L, sceKernelMaxFreeMemSize()); return 2; }
static int l_cpu(lua_State *L) { int mhz = (int)luaL_checkinteger(L, 1); scePowerSetClockFrequency(mhz, mhz, mhz / 2); return 0; }
static int l_exit(lua_State *L) { (void)L; sceKernelExitGame(); return 0; }

static int l_listdir(lua_State *L) { trace("listdir");
    DIR *d = opendir(luaL_checkstring(L, 1));
    if (!d) { lua_pushnil(L); return 1; }
    lua_newtable(L); int i = 1; struct dirent *e;
    while ((e = readdir(d))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        lua_pushstring(L, e->d_name); lua_rawseti(L, -2, i++);
    }
    closedir(d); return 1;
}
static int l_stat(lua_State *L) { trace("stat");
    struct stat st;
    if (stat(luaL_checkstring(L, 1), &st) != 0) { lua_pushnil(L); return 1; }
    lua_pushstring(L, S_ISDIR(st.st_mode) ? "directory" : "file");
    lua_pushnumber(L, (lua_Number)st.st_size); lua_pushnumber(L, (lua_Number)st.st_mtime);
    return 3;
}
static int l_mkdir(lua_State *L) { lua_pushboolean(L, mkdir(luaL_checkstring(L, 1), 0777) == 0); return 1; }
static int l_remove(lua_State *L) {
    const char *p = luaL_checkstring(L, 1);
    lua_pushboolean(L, remove(p) == 0 || rmdir(p) == 0); return 1;
}

static int l_deflate(lua_State *L) { trace("deflate");
    size_t n; const char *s = luaL_checklstring(L, 1, &n);
    uLongf cap = compressBound(n); unsigned char *out = malloc(cap);
    if (compress2(out, &cap, (const Bytef *)s, n, 6) != Z_OK) { free(out); lua_pushnil(L); return 1; }
    lua_pushlstring(L, (char *)out, cap); free(out); return 1;
}
static int l_inflate(lua_State *L) { trace("inflate");
    size_t n; const char *s = luaL_checklstring(L, 1, &n);
    z_stream z; memset(&z, 0, sizeof z);
    if (inflateInit(&z) != Z_OK) { lua_pushnil(L); return 1; }
    size_t cap = n * 4 + 1024, len = 0; unsigned char *out = malloc(cap);
    z.next_in = (Bytef *)s; z.avail_in = n; int r;
    do {
        if (len == cap) { cap *= 2; out = realloc(out, cap); }
        z.next_out = out + len; z.avail_out = cap - len;
        r = inflate(&z, Z_NO_FLUSH);
        len = cap - z.avail_out;
    } while (r == Z_OK);
    inflateEnd(&z);
    if (r != Z_STREAM_END) { free(out); lua_pushnil(L); return 1; }
    lua_pushlstring(L, (char *)out, len); free(out); return 1;
}

/* ---------------------------------------------------------------------- init */
void engine_gu_init(void) {
    sceGuInit();
    sceGuStart(GU_DIRECT, gu_list);
    sceGuDrawBuffer(GU_PSM_8888, (void *)0, 512);
    sceGuDispBuffer(SCR_W, SCR_H, (void *)0x88000, 512);
    sceGuOffset(2048 - SCR_W / 2, 2048 - SCR_H / 2);
    sceGuViewport(2048, 2048, SCR_W, SCR_H);
    sceGuScissor(0, 0, SCR_W, SCR_H);
    sceGuEnable(GU_SCISSOR_TEST);
    sceGuDisable(GU_DEPTH_TEST); sceGuDisable(GU_CULL_FACE);
    sceGuEnable(GU_BLEND);
    sceGuBlendFunc(GU_ADD, GU_SRC_ALPHA, GU_ONE_MINUS_SRC_ALPHA, 0, 0);
    /* framebuffer alpha is the stencil buffer: without this, anything drawn into a canvas ends up with alpha 0 */
    sceGuEnable(GU_STENCIL_TEST); sceGuStencilFunc(GU_ALWAYS, 0xFF, 0xFF); sceGuStencilOp(GU_KEEP, GU_KEEP, GU_REPLACE);
    sceGuTexFunc(GU_TFX_MODULATE, GU_TCC_RGBA);
    sceGuTexWrap(GU_CLAMP, GU_CLAMP);
    sceGuTexScale(1.0f, 1.0f);
    sceGuTexOffset(0.0f, 0.0f);
    sceGuTexEnvColor(0xFFFFFFFF);
    sceGuShadeModel(GU_SMOOTH);
    sceGuFinish(); sceGuSync(0, 0);
    sceDisplayWaitVblankStart();
    sceGuDisplay(GU_TRUE);
    sceCtrlSetSamplingCycle(0);
    sceCtrlSetSamplingMode(PSP_CTRL_MODE_ANALOG);
}

static const luaL_Reg funcs[] = {
    {"image_load", l_image_load}, {"tex_filter", l_tex_filter}, {"draw", l_draw}, {"fill_poly", l_fill_poly},
    {"fill_rect", l_fill_rect}, {"line", l_line}, {"b64encode", l_b64encode}, {"b64decode", l_b64decode}, {"set_color", l_set_color}, {"get_color", l_get_color}, {"push", l_push}, {"pop", l_pop},
    {"prep_draw", l_prep_draw}, {"origin", l_origin}, {"reset_stack", l_reset_stack}, {"translate", l_translate}, {"scale", l_scale}, {"rotate", l_rotate},
    {"stack_depth", l_stack_depth}, {"shear", l_shear}, {"get_matrix", l_get_matrix}, {"set_matrix", l_set_matrix}, {"mul_matrix", l_mul_matrix},
    {"begin_frame", l_begin}, {"clear", l_clear}, {"end_frame", l_end}, {"scissor", l_scissor}, {"blend", l_blend},
    {"font_load", l_font_load}, {"font_width", l_font_width}, {"font_has", l_font_has}, {"font_draw", l_font_draw},
    {"pad", l_pad}, {"time", l_time}, {"sleep", l_sleep}, {"mem", l_mem}, {"tex_mem", l_texmem}, {"canvas_new", l_canvas_new}, {"canvas_set", l_canvas_set}, {"suppress", l_suppress}, {"canvas_pixel", l_canvas_pixel}, {"palette", l_palette}, {"cpu", l_cpu}, {"exit", l_exit},
    {"listdir", l_listdir}, {"stat", l_stat}, {"mkdir", l_mkdir}, {"remove", l_remove},
    {"deflate", l_deflate}, {"inflate", l_inflate}, {NULL, NULL}
};
void audio_register(lua_State *L);
int luaopen_native(lua_State *L) {
    luaL_newmetatable(L, "balatro.tex"); lua_pushcfunction(L, tex_gc); lua_setfield(L, -2, "__gc"); lua_pop(L, 1);
    luaL_newmetatable(L, "balatro.font"); lua_pushcfunction(L, font_gc); lua_setfield(L, -2, "__gc"); lua_pop(L, 1);
    luaL_register(L, "native", funcs);
    audio_register(L);
    return 1;
}
