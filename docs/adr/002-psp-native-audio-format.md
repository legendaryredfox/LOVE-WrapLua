# ADR-002: MP3 decoded on the Media Engine is the only audio format of the native PSP backend

**Date:** 2026-11-17
**Status:** Decided; implementation open

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
