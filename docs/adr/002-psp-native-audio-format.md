# ADR-002: MP3 decoded on the Media Engine is the only audio format of the native PSP backend

**Date:** 2026-11-17
**Status:** Decided; `sceMp3` path implemented (2026-11-21), Ogg and WAV not removed yet, concurrent streams open (see Result)

---

## Context

The native PSP backend mixes audio on the single 333 MHz main core. With the mixer on, Balatro's `SELECTING_HAND`
runs at 11.9 fps against 16.4 fps with every source silent, a cost of about 12.7 ms per frame (see
`docs/NATIVE_PSP_AUDIT.md`). A mixer fast path (no interpolation at pitch 1, tight loops) gave no gain, so the
mixing arithmetic is not the cost. Software Ogg decoding (Tremor) is the likely one. The goal of the repository is a
game the size of Balatro running smoothly, so the audio path has to leave the main core alone.

## Options

| Format | Decoder | Main-core cost | Notes |
|---|---|---|---|
| Ogg Vorbis (today) | Tremor, software | high | the measured problem |
| WAV / raw PCM | none | none, but memory and I/O bound | music does not fit the heap |
| IMA ADPCM | software, a few instructions per sample | low, not zero | 4:1 against PCM, still large files |
| Atrac3 / Atrac3+ | `sceAtrac`, hardware | about zero | no free encoder in ffmpeg |
| MP3 | `sceMp3`, Media Engine | about zero | ffmpeg (`libmp3lame`) encodes it |

## Decision

MP3 is the only format the native PSP backend plays. The Media Engine decodes it through `sceMp3`, so the main core
only mixes already-decoded blocks. It is the lightest option for the main core and it is the lightest on disk
(about 128 kbit/s). Ogg and WAV decoding are removed from the engine once MP3 works; Tremor leaves `native/`.

- **Music** streams through a `sceMp3` handle: the engine feeds the compressed stream and reads PCM back.
- **Short effects** are decoded once at load into PCM, so playing one costs only the mix.
- **Conversion** is a step of `tools/lovepsp.lua package`: it runs `ffmpeg -i in -codec:a libmp3lame -b:a 128k`
  over every `.ogg` / `.wav` in the game and keeps the original file names resolved through `love.audio.newSource`,
  so a game does not change.
- Sample-accurate loops need an encoder with gapless support (LAME writes the tag); a loop point is taken from it.

## Risks to check before removing the old decoders

- `sceMp3` limits concurrent handles; Balatro plays music plus short effects, which the plan above keeps out of it.
  Verify the limit on PPSSPP and on hardware.
- PPSSPP decodes on the host, so its frame times show no Media Engine gain; the cost has to be judged by main-core
  work (instruction counts, `noaudio.flag` A/B) and on a real PSP.
- `love.audio` `seek` and `Source:tell` on a compressed stream are approximate; keep the existing software
  position timing.

## Consequences

- Audio assets are lossy MP3: a one-way conversion at packaging time. The game directory is not modified.
- The mixer keeps its job (volume, pitch, looping, 24 voices) over PCM sources.
- Gate: Balatro `SELECTING_HAND` with audio on within 1 ms of the `noaudio.flag` run in the harness, or the decision
  is revisited (IMA ADPCM is the fallback).

## Result of the first implementation (2026-11-21)

`native/src/audio.c` decodes `.mp3` through `sceMp3` (static decode at load, streaming with a handle per source,
seek by block) and `lovepsp.lua package` converts a game's `.ogg` and `.wav` to stereo MP3. `tests/games/audio` passes
in PPSSPP for static and streamed MP3.

- **Handle limit confirmed:** `sceMp3` has 2 handles (`MP3_MAX_HANDLES` in PPSSPP, the same on the firmware). A static
  decode holds one only while it loads. Streams hold one each for their life.
- **Balatro does not fit:** its sound manager streams `music1` to `music5` together (volumes cross-fade, so all five
  advance) and the ambient loops too. Five or more streams against two handles.
- **Not measured yet:** the Balatro A/B against `noaudio.flag`. It needs the stream question settled first.

### Options for the stream limit

| Option | Cost | Note |
|---|---|---|
| `sceAudiocodec` (`PSP_CODEC_MP3`), one frame per call | parse frame headers in C, one codec buffer per stream | no handle limit of the `sceMp3` kind; `libpspaudiocodec` is already linked; the Media Engine still decodes |
| Pool 2 handles over N streams | reopen and `ResetPlayPositionByFrame` on every swap | decoder warm-up per swap, wrong for tracks that all advance |
| Keep music silent at volume 0 (no decode) | needs a position model for skipped tracks | resumes need a seek; changes nothing for tracks that play |

Next: `sceAudiocodec` per stream, then the Balatro gate. Ogg and WAV stay until then.
