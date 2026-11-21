# ADR-002: MP3 decoded on the Media Engine is the only audio format of the native PSP backend

**Date:** 2026-11-17
**Status:** Decided; implemented on `sceAudiocodec` and the gate is met (2026-11-21); removing Ogg and WAV from the engine is open

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

### Decision on the stream limit

Decoding goes through `sceAudiocodecDecode` (`PSP_CODEC_MP3`), one frame per call, with a codec context per stream. The
file is cut into frames in `native/src/audio.c` (header parse, Xing/Info tag for the frame count, ID3 skipped, seek by
walking frame headers and warming the decoder with two dropped frames). There is no handle count limit; a context holds
Media Engine memory (`neededMem` 0x3b68 bytes each), which bounds the count on real hardware and is not measured.
`sceMp3` is no longer used.

## Measurement (2026-11-21, PPSSPP 1.18 core under RetroArch, Balatro `SELECTING_HAND`, `tools/bench.sh 20000`)

| Run | update + draw | fps |
|---|---|---|
| `noaudio.flag` (silent) | 61.4 ms | 16.3 |
| audio on, Ogg through Tremor | 84.7 ms | 11.8 |
| audio on, MP3 through `sceAudiocodec` | 64.7 ms | 15.4 |

MP3 removes 20 of the 23 ms the audio added. The gate (within 1 ms of silent) is **not met**: 3.3 ms remain. What is left
is the main core's share that is not decoding: the mixer over five or more streams, the file reads per frame, thread
switches, and the `love.audio` calls Balatro makes each frame. Not split yet. The 128 kbit/s MP3 files are 18 MB against
17 MB of Ogg. `tests/games/audio` passes in PPSSPP with five MP3 streams open and playing at once; the decoded peak of a
test tone equals ffmpeg's. Not run on hardware: PPSSPP decodes on the host, so the main-core number is the one that
carries over, the decode time itself is not.

### Where the 3.3 ms were, and the fix

A/B with the mixer switched off, and with the mixer on but the streams returning zeros (no decode, no file reads):

| Run | fps |
|---|---|
| silent | 16.3 |
| sources and API calls, mixer thread off | 16.4 |
| mixer on, streams give zeros | 15.2 |
| mixer on, MP3 decoding | 15.4 |

Decoding, file reads and the `love.audio` calls cost nothing measurable; all of it was the software mixer on the main
core. The Media Engine is a second core, but running the mixer there needs custom ME code in a kernel-mode PRX, which a
user-mode EBOOT cannot load and PPSSPP cannot run, so the mixer stays on the main core and got cheaper: the per-frame
loop with 64-bit positions and a function call per frame is now a tight loop over the stretch that needs no decoding
(`native/src/mix.c`, 32-bit fractions, a straight copy at pitch 1 and 44.1 kHz). The per-frame path stays for the end
of a source, a loop and a window refill. `tests/mix_test.lua` checks the loop against a one-frame reference on the host.

Result, same harness: **16.2 fps with audio on (61.5 ms) against 16.3 silent (61.4 ms)**, so the gate (within 1 ms) is
met. Not run on hardware.

Next: remove the Ogg and WAV decoders and Tremor from `native/` as decided above, and keep `--keep-audio` only if a
reason appears.
