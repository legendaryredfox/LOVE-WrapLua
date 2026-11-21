/* Audio for the native PSP backend: a software mixer on its own thread, feeding one sceAudio channel.
 *
 * Sources are MP3 (decoded on the Media Engine through sceAudiocodec), WAV (PCM 8 or 16 bit) or Ogg Vorbis (Tremor, the
 * integer decoder). A source is decoded whole when it is small ("static") and streamed from the file when it is
 * large or asked to be. Each source plays
 * as its own voice: pitch by linear resampling, volume, looping, pause, seek. Up to MAX_VOICES play at once.
 *
 * Thread model: Lua calls change plain 32-bit fields of a source (atomic on the PSP) and the voice list under
 * a short interrupt-suspend section. The mixer thread owns playback positions and the decoders, and is the only
 * place a source is freed: __gc parks it on a graveyard list that the mixer empties between blocks.
 */
#include <pspkernel.h>
#include <pspaudio.h>
#include <pspthreadman.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <malloc.h>
#include <psputility.h>
#include <pspaudiocodec.h>
#include <tremor/ivorbisfile.h>
#include "mix.h"
#include "lua.h"
#include "lauxlib.h"

#define OUT_RATE    44100
#define BLOCK       1024          /* frames per output block: 23 ms */
#define MAX_VOICES  24
#define STATIC_MAX  (3 * 1024 * 1024)   /* bytes of decoded PCM above which an Ogg file streams */
#define SBUF_FRAMES 2048
#define MP3_FRAME_MAX 1472        /* the longest Layer III frame is 1441 bytes; a multiple of the 64-byte cache line */
#define MP3_PCM     4608          /* one decoded frame: 1152 stereo frames of 16 bits */
#define MP3_CTX     128           /* the codec context the Media Engine reads, 65 words, cache line aligned */

enum { ST_STOPPED = 0, ST_PLAYING = 1, ST_PAUSED = 2 };

typedef struct Pcm {
    int refs;
    int16_t *data;
    long frames;
    int rate, channels;
} Pcm;

/* One MP3 file with its sceAudiocodec context and buffers. The decoder always returns 16-bit stereo, a mono file
 * included. */
typedef struct Mp3 {
    FILE *fp;
    unsigned long *ctx;            /* codec context, see PPSSPP's SceAudiocodecCodec for the layout */
    unsigned char *in;             /* the frame being decoded */
    int16_t *pcm;                  /* its output */
    int ctx_ready;                 /* the Media Engine memory is held */
    int rate, channels;
    long maxout;                   /* frames per decoded block: 1152, or 576 for MPEG-2 rates */
    long frames;                   /* blocks in the file, from the Xing/Info tag or the bit rate */
    long start, end, pos, fpos;    /* file offsets: first audio frame, end of audio, next frame, where fp is */
} Mp3;

typedef struct Src {
    Pcm *pcm;                      /* static: whole decoded file */
    int is_stream;
    FILE *fp;                      /* stream: Tremor reads from this */
    OggVorbis_File vf;
    int vf_open;
    Mp3 m;
    int m_open;
    char path[256];
    int rate, channels;
    long total_frames;

    volatile int state;
    volatile int vol;              /* 0..256 */
    volatile int step;             /* source frames per output frame, 16.16 */
    volatile int loop;
    volatile long seek_to;         /* frame to jump to, or -1 */
    volatile int dead;

    /* playback position, owned by the mixer */
    uint64_t pos;                  /* 16.16 frame index into the whole source, for static and streamed alike */

    int16_t sbuf[SBUF_FRAMES * 2]; /* stream window */
    long sbase;                    /* absolute frame index of sbuf[0] */
    int sfill;                     /* valid frames in sbuf */
    int eof;
} Src;

static Src *voices[MAX_VOICES];
static int nvoices = 0;
static Src *graveyard[64];
static int ngrave = 0;
static volatile int master = 256;
static volatile int started = 0;
static SceUID mixer_thread = -1;

/* ------------------------------------------------------------------ decoding */
static int16_t *read_wav(const char *path, long *frames, int *rate, int *channels) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    unsigned char h[12];
    if (fread(h, 1, 12, f) != 12 || memcmp(h, "RIFF", 4) || memcmp(h + 8, "WAVE", 4)) { fclose(f); return NULL; }
    int fmt_ok = 0, bits = 0, ch = 0, rt = 0;
    for (;;) {
        unsigned char c[8];
        if (fread(c, 1, 8, f) != 8) break;
        unsigned long sz = c[4] | (c[5] << 8) | (c[6] << 16) | ((unsigned long)c[7] << 24);
        if (!memcmp(c, "fmt ", 4)) {
            unsigned char b[16];
            if (sz < 16 || fread(b, 1, 16, f) != 16) break;
            int tag = b[0] | (b[1] << 8);
            ch = b[2] | (b[3] << 8);
            rt = b[4] | (b[5] << 8) | (b[6] << 16) | (b[7] << 24);
            bits = b[14] | (b[15] << 8);
            fmt_ok = (tag == 1 || tag == 0xFFFE) && (ch == 1 || ch == 2) && (bits == 8 || bits == 16);
            if (sz > 16) fseek(f, (long)(sz - 16), SEEK_CUR);
        } else if (!memcmp(c, "data", 4)) {
            if (!fmt_ok) break;
            long bytes = (long)sz, bps = bits / 8 * ch;
            long fr = bytes / bps;
            int16_t *out = malloc((size_t)fr * ch * sizeof(int16_t));
            if (!out) break;
            if (bits == 16) {
                if (fread(out, 2, (size_t)fr * ch, f) != (size_t)fr * ch) { /* truncated file: keep what was read */ }
            } else {
                unsigned char *tmp = malloc((size_t)fr * ch);
                if (!tmp) { free(out); break; }
                size_t got = fread(tmp, 1, (size_t)fr * ch, f);
                for (size_t i = 0; i < (size_t)fr * ch; i++) out[i] = i < got ? (int16_t)((tmp[i] - 128) << 8) : 0;
                free(tmp);
            }
            fclose(f);
            *frames = fr; *rate = rt; *channels = ch;
            return out;
        } else {
            fseek(f, (long)sz + (long)(sz & 1), SEEK_CUR);
        }
    }
    fclose(f);
    return NULL;
}

/* Bytes of an ID3v2 tag at the start of the file, 0 when there is none. */
static long id3_size(FILE *f) {
    unsigned char h[10];
    fseek(f, 0, SEEK_SET);
    if (fread(h, 1, 10, f) != 10 || memcmp(h, "ID3", 3)) return 0;
    long n = ((long)(h[6] & 0x7F) << 21) | ((long)(h[7] & 0x7F) << 14) | ((long)(h[8] & 0x7F) << 7) | (h[9] & 0x7F);
    return 10 + n + ((h[5] & 0x10) ? 10 : 0);
}

/* ---- MP3 on the Media Engine, one frame per sceAudiocodecDecode call. sceMp3 would do the stream parsing but it
 * has 2 handles; a codec context has no count limit, only the Media Engine memory each one holds. The file is cut into frames
 * here and the decoder keeps its own state (bit reservoir, overlap) between calls. */
static char mp3_why[96];           /* the step that failed last, for the message a source gives */
static int mp3_state = 0;          /* 0 untried, 1 ready, -1 the module did not load */

static int mp3_boot(void) {
    if (mp3_state) return mp3_state > 0;
    mp3_state = -1;
    int r = sceUtilityLoadAvModule(PSP_AV_MODULE_AVCODEC);
    if (r < 0) { snprintf(mp3_why, sizeof mp3_why, "loading avcodec: %08x", (unsigned)r); return 0; }
    mp3_state = 1;
    return 1;
}

static void mp3_close(Mp3 *m) {
    if (m->ctx_ready) sceAudiocodecReleaseEDRAM(m->ctx);
    if (m->fp) fclose(m->fp);
    free(m->ctx); free(m->in); free(m->pcm);
    memset(m, 0, sizeof *m);
}

/* Layer III frame header at h: returns the frame length in bytes (0 when it is not a usable header) and fills in the
 * stream parameters. */
static int mp3_header(const unsigned char *h, int *rate, int *channels, int *spf) {
    static const int br1[16] = { 0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0 };
    static const int br2[16] = { 0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0 };
    static const int sr[3] = { 44100, 48000, 32000 };
    if (h[0] != 0xFF || (h[1] & 0xE0) != 0xE0) return 0;
    int ver = (h[1] >> 3) & 3, layer = (h[1] >> 1) & 3, bi = h[2] >> 4, si = (h[2] >> 2) & 3;
    if (ver == 1 || layer != 1 || bi == 0 || bi == 15 || si == 3) return 0;
    int r = sr[si] >> (ver == 3 ? 0 : ver == 2 ? 1 : 2);
    int kbps = ver == 3 ? br1[bi] : br2[bi];
    int len = (ver == 3 ? 144 : 72) * kbps * 1000 / r + ((h[2] >> 1) & 1);
    if (rate) *rate = r;
    if (channels) *channels = ((h[3] >> 6) & 3) == 3 ? 1 : 2;
    if (spf) *spf = ver == 3 ? 1152 : 576;
    return len;
}

/* Positions the file at the next frame and loads it into m->in; returns its length, 0 at the end of the stream. */
static int mp3_read_frame(Mp3 *m) {
    for (int skipped = 0; m->pos + 4 <= m->end && skipped < 8192; skipped++) {
        unsigned char h[4];
        int len;
        if (m->fpos != m->pos) { if (fseek(m->fp, m->pos, SEEK_SET)) return 0; m->fpos = m->pos; }
        if (fread(h, 1, 4, m->fp) != 4) return 0;
        len = mp3_header(h, NULL, NULL, NULL);
        if (len > 4 && len <= MP3_FRAME_MAX && m->pos + len <= m->end) {
            memcpy(m->in, h, 4);
            if (fread(m->in + 4, 1, (size_t)(len - 4), m->fp) != (size_t)(len - 4)) return 0;
            m->pos += len; m->fpos = m->pos;
            return len;
        }
        m->pos++; m->fpos = -1;                       /* not a frame here: look at the next byte */
    }
    return 0;
}

/* Skips the frames before `block` without decoding them. */
static void mp3_skip_to(Mp3 *m, long block) {
    m->pos = m->start; m->fpos = -1;
    for (long i = 0; i < block; i++) {
        unsigned char h[4];
        if (fseek(m->fp, m->pos, SEEK_SET) || fread(h, 1, 4, m->fp) != 4) break;
        int len = mp3_header(h, NULL, NULL, NULL);
        if (len <= 4) break;
        m->pos += len;
    }
    m->fpos = -1;
}

/* Decodes the next frame; returns its stereo frames (valid until the next call), 0 at the end of the file. */
static long mp3_next(Mp3 *m, const int16_t **out) {
    for (int tries = 0; tries < 16; tries++) {
        int len = mp3_read_frame(m);
        if (!len) return 0;
        m->ctx[6] = (unsigned long)m->in;
        m->ctx[7] = (unsigned long)len;               /* the input size: older emulators read it from here */
        m->ctx[8] = (unsigned long)m->pcm;
        m->ctx[9] = MP3_PCM;                          /* and the room for the output */
        sceKernelDcacheWritebackInvalidateRange(m->in, MP3_FRAME_MAX);
        sceKernelDcacheWritebackInvalidateRange(m->ctx, 0x80);
        int r = sceAudiocodecDecode(m->ctx, PSP_CODEC_MP3);
        sceKernelDcacheWritebackInvalidateRange(m->ctx, 0x80);
        sceKernelDcacheWritebackInvalidateRange(m->pcm, MP3_PCM);
        if (r < 0 || (int)m->ctx[9] <= 0) continue;     /* a frame that does not decode is skipped */
        *out = m->pcm;
        return (long)m->ctx[9] / 4;
    }
    return 0;
}

/* Makes the next mp3_next return block `block`. The two frames before it are decoded and dropped so the decoder's
 * bit reservoir and overlap are warm. */
static int mp3_seek_block(Mp3 *m, long block) {
    long pre = block < 2 ? block : 2;
    const int16_t *dump;
    mp3_skip_to(m, block - pre);
    for (long i = 0; i < pre; i++) if (!mp3_next(m, &dump)) break;
    return 1;
}

static int mp3_open(Mp3 *m, const char *path) {
    memset(m, 0, sizeof *m);
    if (!mp3_boot()) return 0;
    m->fp = fopen(path, "rb");
    if (!m->fp) { snprintf(mp3_why, sizeof mp3_why, "cannot open the file"); return 0; }
    long start = id3_size(m->fp);
    fseek(m->fp, 0, SEEK_END);
    long end = ftell(m->fp);
    if (end >= 128) {                                 /* an ID3v1 tag ends the file */
        char tag[3];
        fseek(m->fp, end - 128, SEEK_SET);
        if (fread(tag, 1, 3, m->fp) == 3 && !memcmp(tag, "TAG", 3)) end -= 128;
    }
    m->ctx = memalign(64, MP3_CTX);
    m->in = memalign(64, MP3_FRAME_MAX);
    m->pcm = memalign(64, MP3_PCM);
    if (end <= start || !m->ctx || !m->in || !m->pcm) { snprintf(mp3_why, sizeof mp3_why, "empty file or out of memory"); mp3_close(m); return 0; }
    m->start = start; m->end = end; m->pos = start; m->fpos = -1;

    int len = mp3_read_frame(m);
    int spf = 0;
    if (!len || !mp3_header(m->in, &m->rate, &m->channels, &spf)) { snprintf(mp3_why, sizeof mp3_why, "no MP3 frame found"); mp3_close(m); return 0; }
    m->maxout = spf;
    m->frames = 0;
    {   /* the first frame of an encoder's file is often a tag (Xing or Info) holding the frame count, not audio */
        int n = len < 64 ? len : 64;
        for (int i = 4; i + 12 <= n; i++) {
            if (!memcmp(m->in + i, "Xing", 4) || !memcmp(m->in + i, "Info", 4)) {
                unsigned long flags = ((unsigned long)m->in[i + 4] << 24) | (m->in[i + 5] << 16) | (m->in[i + 6] << 8) | m->in[i + 7];
                if (flags & 1) m->frames = (long)(((unsigned long)m->in[i + 8] << 24) | (m->in[i + 9] << 16) | (m->in[i + 10] << 8) | m->in[i + 11]);
                m->start = m->pos;                    /* audio starts after the tag frame */
                break;
            }
        }
        if (m->start == start) m->pos = start;        /* the first frame is audio: decode it too */
    }
    if (m->frames <= 0) m->frames = (m->end - m->start) / len;   /* constant bit rate estimate */

    memset(m->ctx, 0, MP3_CTX);
    m->ctx[5] = 1;                                    /* inited */
    int r = sceAudiocodecCheckNeedMem(m->ctx, PSP_CODEC_MP3);
    if (r < 0) { snprintf(mp3_why, sizeof mp3_why, "sceAudiocodecCheckNeedMem: %08x", (unsigned)r); mp3_close(m); return 0; }
    r = sceAudiocodecGetEDRAM(m->ctx, PSP_CODEC_MP3);
    if (r < 0) { snprintf(mp3_why, sizeof mp3_why, "sceAudiocodecGetEDRAM: %08x", (unsigned)r); mp3_close(m); return 0; }
    m->ctx_ready = 1;
    m->ctx[10] = 0x5A1;                               /* largest frame, the decoder's upper bound for the input */
    r = sceAudiocodecInit(m->ctx, PSP_CODEC_MP3);
    if (r < 0) { snprintf(mp3_why, sizeof mp3_why, "sceAudiocodecInit: %08x", (unsigned)r); mp3_close(m); return 0; }
    m->pos = m->start; m->fpos = -1;
    return 1;
}

/* Decodes a whole MP3 file; returns NULL when it is too large (the caller then streams it). The output is stereo. */
static int16_t *read_mp3_static(const char *path, long *frames, int *rate, int *channels, int *too_big) {
    Mp3 m;
    *too_big = 0;
    if (!mp3_open(&m, path)) return NULL;
    long est = m.frames * m.maxout;
    if (est * 4 > STATIC_MAX) { *too_big = 1; mp3_close(&m); return NULL; }
    long cap = (est > 0 ? est : 65536) + 2 * m.maxout, got = 0;
    int16_t *out = malloc((size_t)cap * 4);
    for (;;) {
        const int16_t *blk = NULL;
        long fr;
        if (!out) break;
        fr = mp3_next(&m, &blk);
        if (fr <= 0) break;
        if (got + fr > cap) {
            if ((got + fr) * 4 > STATIC_MAX) { free(out); out = NULL; *too_big = 1; break; }
            cap = (got + fr) * 2;
            if (cap * 4 > STATIC_MAX) cap = STATIC_MAX / 4;
            int16_t *grown = realloc(out, (size_t)cap * 4);
            if (!grown) { free(out); out = NULL; break; }
            out = grown;
        }
        memcpy(out + got * 2, blk, (size_t)fr * 4);
        got += fr;
    }
    *frames = got; *rate = m.rate; *channels = m.channels;
    mp3_close(&m);
    if (out && got <= 0) { free(out); out = NULL; }
    return out;
}

/* Decodes a whole Ogg file; returns NULL when it is too large (the caller then streams it). */
static int16_t *read_ogg_static(const char *path, long *frames, int *rate, int *channels, int *too_big) {
    FILE *f = fopen(path, "rb");
    *too_big = 0;
    if (!f) return NULL;
    OggVorbis_File vf;
    if (ov_open(f, &vf, NULL, 0) < 0) { fclose(f); return NULL; }
    vorbis_info *vi = ov_info(&vf, -1);
    long total = (long)ov_pcm_total(&vf, -1);
    if (!vi || total <= 0 || (vi->channels != 1 && vi->channels != 2)) { ov_clear(&vf); return NULL; }
    long bytes = total * vi->channels * 2;
    if (bytes > STATIC_MAX) { *too_big = 1; ov_clear(&vf); return NULL; }
    int16_t *out = malloc((size_t)bytes);
    if (!out) { ov_clear(&vf); return NULL; }
    long got = 0;
    while (got < bytes) {
        int bs;
        long r = ov_read(&vf, (char *)out + got, (int)(bytes - got > 4096 ? 4096 : bytes - got), &bs);
        if (r <= 0) break;
        got += r;
    }
    *frames = got / (vi->channels * 2); *rate = (int)vi->rate; *channels = vi->channels;
    ov_clear(&vf);
    return out;
}

static int ends_with(const char *s, const char *ext);

static int stream_open(Src *s) {
    if (ends_with(s->path, ".mp3")) {
        if (!mp3_open(&s->m, s->path)) return 0;
        s->m_open = 1;
        s->rate = s->m.rate; s->channels = s->m.channels;
        s->total_frames = s->m.frames * s->m.maxout;
        return 1;
    }
    s->fp = fopen(s->path, "rb");
    if (!s->fp) return 0;
    if (ov_open(s->fp, &s->vf, NULL, 0) < 0) { fclose(s->fp); s->fp = NULL; return 0; }
    s->vf_open = 1;
    vorbis_info *vi = ov_info(&s->vf, -1);
    if (!vi || (vi->channels != 1 && vi->channels != 2)) { ov_clear(&s->vf); s->vf_open = 0; s->fp = NULL; return 0; }
    s->rate = (int)vi->rate; s->channels = vi->channels;
    s->total_frames = (long)ov_pcm_total(&s->vf, -1);
    return 1;
}

static void src_free(Src *s) {
    if (s->pcm && --s->pcm->refs == 0) { free(s->pcm->data); free(s->pcm); }
    if (s->vf_open) ov_clear(&s->vf);      /* closes the FILE it was given */
    if (s->m_open) mp3_close(&s->m);
    free(s);
}

/* ------------------------------------------------------------------ mixer */
static void rewind_src(Src *s) {
    s->pos = 0;
    if (s->is_stream) {
        if (s->vf_open) ov_pcm_seek(&s->vf, 0);
        if (s->m_open) mp3_seek_block(&s->m, 0);
        s->sbase = 0; s->sfill = 0; s->eof = 0;
    }
}

/* Decodes the next stretch of a streamed source as stereo frames at dst; returns the frames, 0 at the end. */
static long stream_read(Src *s, int16_t *dst) {
    if (s->m_open) {
        const int16_t *blk = NULL;
        long fr = mp3_next(&s->m, &blk);
        if (fr > 0) memcpy(dst, blk, (size_t)fr * 4);
        return fr;
    }
    int bs;
    long bytes = ov_read(&s->vf, (char *)dst, 1024 * s->channels * 2, &bs);
    if (bytes <= 0) return 0;
    long fr = bytes / (s->channels * 2);
    if (s->channels == 1) {                          /* expand mono in place, last frame first */
        for (long i = fr - 1; i >= 0; i--) { int16_t v = dst[i]; dst[i * 2] = v; dst[i * 2 + 1] = v; }
    }
    return fr;
}

/* Streams: make frames [idx, idx + 1] available in sbuf; returns 0 at the end of the file. */
static int stream_ensure(Src *s, long idx) {
    for (;;) {
        if (idx + 1 < s->sbase + s->sfill) return 1;
        if (s->eof) return idx < s->sbase + s->sfill;
        /* keep the last frame so interpolation can look back, then decode forward */
        int keep = s->sfill > 0 ? 1 : 0;
        if (keep) {
            s->sbuf[0] = s->sbuf[(s->sfill - 1) * 2]; s->sbuf[1] = s->sbuf[(s->sfill - 1) * 2 + 1];
            s->sbase += s->sfill - 1;
            s->sfill = 1;
        }
        long fr = stream_read(s, s->sbuf + s->sfill * 2);
        if (fr <= 0) { s->eof = 1; if (!keep) s->sfill = 0; continue; }
        s->sfill += (int)fr;
    }
}

/* Mixes up to `n` output frames of one source into acc (stereo int32). Returns frames produced. */
static void mix_voice(Src *s, int32_t *acc, int n) {
    int vol = (s->vol * master) >> 8;
    long total = s->is_stream ? s->total_frames : s->pcm->frames;
    if (s->seek_to >= 0) {
        long t = s->seek_to; s->seek_to = -1;
        if (t < 0) t = 0;
        if (t >= total) t = total > 0 ? total - 1 : 0;
        if (s->is_stream) {
            long base = t;
            if (s->vf_open) ov_pcm_seek(&s->vf, t);
            if (s->m_open) { base = t / s->m.maxout * s->m.maxout; mp3_seek_block(&s->m, t / s->m.maxout); }
            s->sbase = base; s->sfill = 0; s->eof = 0;
        }
        s->pos = (uint64_t)t << 16;
    }
    for (int i = 0; i < n; i++) {
        {   /* the stretch that needs no decoding and no end-of-source care is mixed in one tight loop */
            const int16_t *d; int ch; long i0, limit;
            if (s->is_stream) { d = s->sbuf; ch = 2; i0 = (long)(s->pos >> 16) - s->sbase; limit = s->sfill; }
            else { d = s->pcm->data; ch = s->pcm->channels; i0 = (long)(s->pos >> 16); limit = s->pcm->frames; }
            if (i0 >= 0 && i0 < limit) {
                long cnt = mix_run(d, ch, i0, (uint32_t)(s->pos & 0xFFFF), (uint32_t)s->step, limit - 1 - i0, vol, acc + i * 2, n - i);
                if (cnt > 0) { s->pos += (uint64_t)cnt * (uint32_t)s->step; i += (int)cnt - 1; continue; }
            }
        }
        long idx; int frac = (int)((s->pos >> 0) & 0xFFFF);
        int l0, r0, l1, r1;
        if (s->is_stream) {
            long abs_idx = (long)(s->pos >> 16);
            if (!stream_ensure(s, abs_idx)) goto ended;
            idx = abs_idx - s->sbase;
            if (idx + 1 >= s->sfill) goto ended;
            l0 = s->sbuf[idx * 2]; r0 = s->sbuf[idx * 2 + 1];
            l1 = s->sbuf[idx * 2 + 2]; r1 = s->sbuf[idx * 2 + 3];
        } else {
            idx = (long)(s->pos >> 16);
            if (idx >= s->pcm->frames) goto ended;
            const int16_t *d = s->pcm->data;
            long nx = idx + 1 < s->pcm->frames ? idx + 1 : idx;
            if (s->pcm->channels == 2) {
                l0 = d[idx * 2]; r0 = d[idx * 2 + 1]; l1 = d[nx * 2]; r1 = d[nx * 2 + 1];
            } else { l0 = r0 = d[idx]; l1 = r1 = d[nx]; }
        }
        {
            int l = l0 + (((l1 - l0) * frac) >> 16), r = r0 + (((r1 - r0) * frac) >> 16);
            acc[i * 2] += (l * vol) >> 8; acc[i * 2 + 1] += (r * vol) >> 8;
        }
        s->pos += (uint64_t)s->step;
        continue;
    ended:
        if (s->loop) {
            rewind_src(s);
            if (total <= 0) { s->state = ST_STOPPED; return; }
            i--;                                  /* redo this output frame from the start */
            continue;
        }
        s->state = ST_STOPPED;
        rewind_src(s);
        return;
    }
}

static void drain_graveyard(void) {
    for (;;) {
        Src *s = NULL;
        int f = sceKernelCpuSuspendIntr();
        if (ngrave > 0) s = graveyard[--ngrave];
        sceKernelCpuResumeIntr(f);
        if (!s) return;
        src_free(s);
    }
}

static int16_t outbuf[2][BLOCK * 2] __attribute__((aligned(64)));

static int mixer_main(SceSize args, void *argp) {
    int ch = sceAudioChReserve(PSP_AUDIO_NEXT_CHANNEL, BLOCK, PSP_AUDIO_FORMAT_STEREO);
    int cur = 0;
    static int32_t acc[BLOCK * 2];
    while (started) {
        drain_graveyard();
        Src *snap[MAX_VOICES]; int n;
        int f = sceKernelCpuSuspendIntr();
        n = nvoices;
        for (int i = 0; i < n; i++) snap[i] = voices[i];
        sceKernelCpuResumeIntr(f);
        memset(acc, 0, sizeof acc);
        for (int i = 0; i < n; i++) if (snap[i]->state == ST_PLAYING && !snap[i]->dead) mix_voice(snap[i], acc, BLOCK);
        int16_t *o = outbuf[cur];
        for (int i = 0; i < BLOCK * 2; i++) { int v = acc[i]; o[i] = (int16_t)(v > 32767 ? 32767 : v < -32768 ? -32768 : v); }
        /* finished voices leave the list */
        f = sceKernelCpuSuspendIntr();
        for (int i = 0; i < nvoices; ) {
            if (voices[i]->state != ST_PLAYING) { voices[i] = voices[--nvoices]; } else i++;
        }
        sceKernelCpuResumeIntr(f);
        if (ch >= 0) sceAudioOutputBlocking(ch, PSP_AUDIO_VOLUME_MAX, o);
        else sceKernelDelayThread(23000);
        cur ^= 1;
    }
    if (ch >= 0) sceAudioChRelease(ch);
    return 0;
}

static void ensure_mixer(void) {
    if (started) return;
    started = 1;
    mixer_thread = sceKernelCreateThread("audio", mixer_main, 0x12, 0x4000, 0, NULL);
    if (mixer_thread >= 0) sceKernelStartThread(mixer_thread, 0, NULL);
    else started = 0;
}

/* ------------------------------------------------------------------ Lua API */
#define SRC "psp.source"
static Src *check_src(lua_State *L, int i) {
    Src **p = luaL_checkudata(L, i, SRC);
    if (!*p) luaL_error(L, "source was released");
    return *p;
}

static void set_step(Src *s, double pitch) {
    if (pitch < 0.05) pitch = 0.05;
    if (pitch > 8) pitch = 8;
    s->step = (int)((double)s->rate / OUT_RATE * pitch * 65536.0);
    if (s->step < 1) s->step = 1;
}

static Src *new_src(void) {
    Src *s = calloc(1, sizeof(Src));
    if (!s) return NULL;
    s->vol = 256; s->seek_to = -1;
    return s;
}

static int push_src(lua_State *L, Src *s) {
    Src **p = lua_newuserdata(L, sizeof(Src *));
    *p = s;
    luaL_getmetatable(L, SRC); lua_setmetatable(L, -2);
    return 1;
}

static int ends_with(const char *s, const char *ext) {
    size_t a = strlen(s), b = strlen(ext);
    if (a < b) return 0;
    for (size_t i = 0; i < b; i++) {
        char c = s[a - b + i]; if (c >= 'A' && c <= 'Z') c += 32;
        if (c != ext[i]) return 0;
    }
    return 1;
}

/* audio_new(path [, stream]) -> source | nil, message */
static int l_audio_new(lua_State *L) {
    const char *path = luaL_checkstring(L, 1);
    int want_stream = lua_toboolean(L, 2);
    Src *s = new_src();
    if (!s) { lua_pushnil(L); lua_pushstring(L, "out of memory"); return 2; }
    strncpy(s->path, path, sizeof s->path - 1);
    int ogg = ends_with(path, ".ogg"), wav = ends_with(path, ".wav"), mp3 = ends_with(path, ".mp3");
    if (!ogg && !wav && !mp3) { free(s); lua_pushnil(L); lua_pushstring(L, "unsupported audio format (use .mp3, .ogg or .wav)"); return 2; }
    if (wav) {
        Pcm *pcm = calloc(1, sizeof(Pcm));
        long fr; int rt, ch;
        int16_t *d = pcm ? read_wav(path, &fr, &rt, &ch) : NULL;
        if (!d) { free(pcm); free(s); lua_pushnil(L); lua_pushstring(L, "could not read the WAV file"); return 2; }
        pcm->data = d; pcm->frames = fr; pcm->rate = rt; pcm->channels = ch; pcm->refs = 1;
        s->pcm = pcm; s->rate = rt; s->channels = ch; s->total_frames = fr;
    } else {
        int too_big = 0;
        const char *what = mp3 ? "MP3" : "Ogg";
        if (!want_stream) {
            Pcm *pcm = calloc(1, sizeof(Pcm));
            long fr; int rt, ch;
            int16_t *d = !pcm ? NULL : mp3 ? read_mp3_static(path, &fr, &rt, &ch, &too_big) : read_ogg_static(path, &fr, &rt, &ch, &too_big);
            if (d) {
                pcm->data = d; pcm->frames = fr; pcm->rate = rt; pcm->channels = mp3 ? 2 : ch; pcm->refs = 1;
                s->pcm = pcm; s->rate = rt; s->channels = ch; s->total_frames = fr;
            } else {
                free(pcm);
                if (!too_big) { free(s); lua_pushnil(L); lua_pushfstring(L, "could not decode the %s file%s%s", what, mp3 ? ": " : "", mp3 ? mp3_why : ""); return 2; }
                want_stream = 1;
            }
        }
        if (want_stream) {
            s->is_stream = 1;
            if (!stream_open(s)) { free(s); lua_pushnil(L); lua_pushfstring(L, "could not open the %s file%s%s", what, mp3 ? ": " : "", mp3 ? mp3_why : ""); return 2; }
        }
    }
    set_step(s, 1.0);
    return push_src(L, s);
}

static int l_audio_gc(lua_State *L) {
    Src **p = lua_touserdata(L, 1);
    Src *s = *p;
    if (!s) return 0;
    *p = NULL;
    s->dead = 1;
    int f = sceKernelCpuSuspendIntr();
    for (int i = 0; i < nvoices; i++) if (voices[i] == s) { voices[i] = voices[--nvoices]; break; }
    if (ngrave < 64) graveyard[ngrave++] = s; else s = NULL;
    sceKernelCpuResumeIntr(f);
    if (!s) { /* graveyard full: leak this one rather than free under the mixer */ }
    if (started == 0) drain_graveyard();
    return 0;
}

static int l_audio_play(lua_State *L) {
    Src *s = check_src(L, 1);
    ensure_mixer();
    if (s->state == ST_PLAYING) { lua_pushboolean(L, 1); return 1; }
    int f = sceKernelCpuSuspendIntr();
    int listed = 0;
    for (int i = 0; i < nvoices; i++) if (voices[i] == s) listed = 1;
    if (!listed && nvoices < MAX_VOICES) voices[nvoices++] = s; else if (!listed) { sceKernelCpuResumeIntr(f); lua_pushboolean(L, 0); return 1; }
    s->state = ST_PLAYING;
    sceKernelCpuResumeIntr(f);
    lua_pushboolean(L, 1);
    return 1;
}
static int l_audio_pause(lua_State *L) { Src *s = check_src(L, 1); if (s->state == ST_PLAYING) s->state = ST_PAUSED; return 0; }
static int l_audio_stop(lua_State *L) {
    Src *s = check_src(L, 1);
    s->state = ST_STOPPED;
    s->seek_to = 0;                      /* the mixer rewinds when it next sees the source, or on the next play */
    s->pos = 0;
    return 0;
}
static int l_audio_volume(lua_State *L) {
    Src *s = check_src(L, 1);
    double v = luaL_checknumber(L, 2);
    s->vol = (int)(v < 0 ? 0 : v > 4 ? 1024 : v * 256.0);
    return 0;
}
static int l_audio_pitch(lua_State *L) { Src *s = check_src(L, 1); set_step(s, luaL_checknumber(L, 2)); return 0; }
static int l_audio_loop(lua_State *L) { Src *s = check_src(L, 1); s->loop = lua_toboolean(L, 2); return 0; }
static int l_audio_playing(lua_State *L) { lua_pushboolean(L, check_src(L, 1)->state == ST_PLAYING); return 1; }
static int l_audio_paused(lua_State *L) { lua_pushboolean(L, check_src(L, 1)->state == ST_PAUSED); return 1; }
static int l_audio_tell(lua_State *L) {
    Src *s = check_src(L, 1);
    lua_pushnumber(L, (double)(long)(s->pos >> 16) / (s->rate ? s->rate : 1));
    return 1;
}
static int l_audio_seek(lua_State *L) {
    Src *s = check_src(L, 1);
    double t = luaL_checknumber(L, 2);
    s->seek_to = (long)(t * s->rate);
    return 0;
}
static int l_audio_duration(lua_State *L) {
    Src *s = check_src(L, 1);
    lua_pushnumber(L, (double)s->total_frames / (s->rate ? s->rate : 1));
    return 1;
}
static int l_audio_info(lua_State *L) {
    Src *s = check_src(L, 1);
    lua_pushinteger(L, s->rate); lua_pushinteger(L, s->channels); lua_pushboolean(L, s->is_stream);
    return 3;
}
/* A static source shares its decoded data; a streamed one opens the file again. */
static int l_audio_clone(lua_State *L) {
    Src *o = check_src(L, 1);
    Src *s = new_src();
    if (!s) { lua_pushnil(L); return 1; }
    strncpy(s->path, o->path, sizeof s->path);
    s->rate = o->rate; s->channels = o->channels; s->total_frames = o->total_frames;
    s->vol = o->vol; s->step = o->step; s->loop = o->loop;
    if (o->is_stream) {
        s->is_stream = 1;
        if (!stream_open(s)) { free(s); lua_pushnil(L); return 1; }
    } else { s->pcm = o->pcm; s->pcm->refs++; }
    return push_src(L, s);
}
static int l_audio_master(lua_State *L) {
    if (lua_isnone(L, 1)) { lua_pushnumber(L, master / 256.0); return 1; }
    double v = luaL_checknumber(L, 1);
    master = (int)(v < 0 ? 0 : v > 1 ? 256 : v * 256.0);
    return 0;
}
static int l_audio_count(lua_State *L) { lua_pushinteger(L, nvoices); return 1; }

static const luaL_Reg audio_funcs[] = {
    {"audio_new", l_audio_new}, {"audio_play", l_audio_play}, {"audio_pause", l_audio_pause}, {"audio_stop", l_audio_stop},
    {"audio_volume", l_audio_volume}, {"audio_pitch", l_audio_pitch}, {"audio_loop", l_audio_loop},
    {"audio_is_playing", l_audio_playing}, {"audio_is_paused", l_audio_paused}, {"audio_tell", l_audio_tell},
    {"audio_seek", l_audio_seek}, {"audio_duration", l_audio_duration}, {"audio_info", l_audio_info},
    {"audio_clone", l_audio_clone}, {"audio_master", l_audio_master}, {"audio_count", l_audio_count},
    {NULL, NULL}
};

/* Adds the audio functions to the table on top of the stack (the `native` module). */
void audio_register(lua_State *L) {
    luaL_newmetatable(L, SRC);
    lua_pushcfunction(L, l_audio_gc); lua_setfield(L, -2, "__gc");
    lua_pop(L, 1);
    for (const luaL_Reg *r = audio_funcs; r->name; r++) { lua_pushcfunction(L, r->func); lua_setfield(L, -2, r->name); }
}
