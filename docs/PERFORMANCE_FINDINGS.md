# Performance findings

Findings from running a large LÖVE game (Balatro) against this wrapper and a native PSP engine, and from
profiling the wrapper itself. It records what was measured, what was changed (branches
`fix/onelua-no-copyscale` and `perf/wrapper-hot-paths`), and what is still open, so the next person can
pick items up without redoing the measurements.

Measured on the test mocks (Lua 5.1) and in PPSSPP (RetroArch core). Nothing here was measured on real
hardware yet. The PPSSPP timing model is deterministic but optimistic: it does not model the 16 KB data
cache of a real PSP.

## 1. Cost model

- A console runs roughly 3 million Lua VM instructions per second (about 0.3 µs each, measured on PSP in
  PPSSPP). 100 instructions is about 30 µs; a 60 fps frame has a budget of roughly 50k instructions, a
  30 fps frame 100k.
- What matters is VM instructions, allocations, and Lua-to-C crossings. Compiler flags for the VM (`-O3`)
  made no difference; a computed-goto VM loop gained about 2 %; building Lua with `float` instead of
  `double` numbers gained about 30 % on the Allegrex (single-precision FPU only).
- Garbage collection was not the bottleneck: about 0.2 ms per frame at the game's own step budget. The
  Lua heap stabilised (6.5-7.5 MB) in a 90 000-frame run.
- File I/O is expensive on OneLua under PPSSPP (about 11 ms per call): avoid per-frame `getInfo` and
  directory listings.

## 2. OneLua PSP EBOOT (v4R1) facts

The `EBOOT.PBP` in this repository is byte-identical to stock ONElua v4R1. No newer PSP build or source
exists upstream (only Vita binaries), so the wrapper has to work with this API. Probed with a tiny script
in PPSSPP:

| API | Behaviour |
|---|---|
| `image.copyscale` | does not exist |
| `image.resize(img, w, h)` | scales every later whole-image `blit` on the GPU |
| `image.scale` | no visible effect |
| sub-rectangle `blit(img, x, y, sx, sy, sw, sh)` | ignores any scale, draws 1:1 |
| `screen.clip(x, y, w, h)` / `screen.clip()` | clips later draws / resets |
| `image.center(img, cx, cy)` | cx, cy are in **unscaled** sheet pixels; that point is placed at the blit x, y and is the rotation pivot (otherwise the pivot is the top-left corner) |
| `image.new(w, h)` | errors |
| `image.loadv` + `blitsprite(frame)` | frames drawn 1:1, no scaling |

Textures must be powers of two up to 512. The runtime image functions live at vaddr = file offset - 0x60
in the PRX (`luaL_Reg` tables); the PRX is type 0xFFA0, so most analysis tools reject it, but
`psp-objdump -d -mmips:allegrex -EL` (from the `pspdev/pspdev` docker image) works.

Decompiled with Ghidra (12.1.3 + ghidra-allegrex, loader "PSP Executable (ELF)"; relocations of the PRX are not applied but the code decompiles): the rotated blit routine slices the image into 64-pixel columns and issues one `sceGuDrawArray` (4 vertices, triangle strip) with a 80-byte allocation per column, so a rotated draw costs `ceil(width / 64)` GPU draws. Unrotated blits take a separate path. The binary has 5966 functions without names.

## 3. Done on `fix/onelua-no-copyscale` (issue #3)

Scaled, mirrored and rotated draws on EBOOTs without `copyscale`: resize the whole sheet, blit it whole,
clip to the wanted rectangle, and pivot with `image.center`. Also a scissor (`screen.clip`) for the PSP,
the missing `oy` argument of `draw(image, quad, x, y, r, sx, sy, ox, oy)` (it was dropped).

## 4. Done on `perf/wrapper-hot-paths`

Synthetic Balatro-sized frame (`tests/bench/frame_cost.lua`: 213 push/translate/scale/pop, 168 `setColor`,
124 draws of which 60 % plain quads, 25 % scaled, 15 % rotated, 54 polygon fills, 45 prints), VM
instructions per frame:

| backend | before | after |
|---|---|---|
| PSP | 243k | 122k |
| OneLua | 223k | 102k |
| lpp-vita | 237k | 115k |
| PS3 | 344k | 195k |

Garbage per frame dropped from about 29 KB to about 2 KB. At 0.3 µs per instruction the PSP number is an
estimate of about 81 ms to about 41 ms per frame; it was not measured with the game running through the
wrapper.

What changed:
- `polygon("fill")` was about 60 % of the synthetic frame (scanline rasteriser in Lua on every call). It
  now emits merged rectangles and caches them per vertex table, keyed by a fingerprint of the current
  transform (scale, fractional offset, checksum).
- `setColor` updates the colour tuple in place, returns early when unchanged, and memoises native colour
  handles (bounded to 1024).
- The transform stack recycles popped levels instead of allocating a table per `push`.
- `turnedBounds` and the 9-argument `draw` no longer allocate tables; `util.to255` uses a local `floor`.

Per-call numbers (PSP backend): `setColor` 92 -> 37 instructions and 352 -> 0 bytes; push/translate/pop
165 -> 175 instructions but 704 -> 0 bytes; `draw(img, quad, ...)` 229 -> 213; scaled and rotated quad
590 -> 523 instructions and 513 -> about 1 byte.

Tools added: `tests/bench/vm_cost.lua`, `vm_profile.lua`, `alloc_cost.lua`, `frame_cost.lua` (with
`--check` against `frame_baseline.lua`, fails on a regression above 10 %), `api_coverage.lua`.
Tests: `noscale_test.lua`, `hotpath_test.lua`, `polyfill_runs_test.lua`, `scissor_test.lua`.

## 5. Open findings that could improve the wrapper

Ordered roughly by expected gain per effort. Each item states the evidence.

1. **Specialise `draw` / quad draw per Image and Quad** (evidence: `vm_profile`: `imagedraw` 124-150
   instructions, `texinset` 10, `psp/state.blitImage` 23). Precompute the inset, the blit function (colour
   and blend) and the scale once per Image/Quad and close over them. Target at most 120 instructions per
   draw on OneLua/PSP.
2. **lpp-vita `draw` with quad: 357 instructions.** Map directly to `Graphics.drawImageExtended` /
   `vita2d_draw_texture_part_scale_rotate`, which scale and rotate on the GPU. Target at most 200.
3. **PS3 `circle` / `ellipse` / `polygon("fill")`: 17 300 instructions per circle.** Cache points per
   (radius, segments) and use a fast convex fill.
4. **3DS: `setColor` 177 and `print` 261 instructions.** Apply the same memoisation as the PSP `setColor`
   and cache text metrics.
5. **`print` / `printf`:** cache width and line breaking per (font, string); avoid `gmatch` per frame
   (72-261 instructions per call depending on backend).
6. **`push` / `translate` / `pop`:** flatten incrementally instead of recomputing the whole stack, and skip
   `applyScissor` when no scissor is active (`transform.lua`: 104 instructions per 3 ops).
7. **State setters** (`setBlendMode`, `setLineWidth`, `setFont`, `setShader`): return early when the value
   is unchanged.
8. **Main loop:** `timestep`, `event.pump` and `keyboard` allocate tables each frame; skip `love.draw`
   when the accumulator needs to catch up (`script.lua`, `core/timestep.lua`). Estimated 0.5-2 ms per
   frame.
9. **Filesystem:** cache `getInfo` / `getDirectoryItems` (a manifest) and read each file once.
10. **Capability detection:** choose the fastest path per EBOOT at start-up (`copyscale`, `clip`,
    `center`, `blitsprite`) and expose it in `love._backend`.
11. **Deferred, depth-sorted draw list** (as used by another Lua game studied locally): record draw
    commands in reused tables per layer, sort by layer, replay. It lets the wrapper group by texture and
    state without touching game code.
12. **`SpriteBatch`, `Text`, `ParticleSystem`:** store in compact arrays and replay with a tight loop; use
    a native batch where the backend has one.
13. **Performance CI:** run `vm_cost.lua` and `alloc_cost.lua` on every backend with thresholds
    (for example fail if `setColor` exceeds 60 instructions).
14. **API coverage:** `api_coverage.lua` found the functions Balatro (64 of 78) and the other game
    studied (85 of 106) call that are not defined on the PSP backend. Candidates by frequency:
    `love.thread.*`, `love.mouse.*`, `love.sound.newSoundData`, `love.image.newImageData`. The script's
    module loading is partial, so treat its "missing" list as approximate until refined.
15. **Native PSP backend** (the largest possible gain on PSP): a runtime that keeps this wrapper's
    contract but draws through a native engine (sceGu) with GPU scale, rotation and tint, tiles for
    textures above 512, and TrueType fonts. A working native engine with a LÖVE-compatible Lua layer
    exists outside this repository; packaging it as an alternative runtime is the proposal. It measured
    about 14 frames per second on a full Balatro scene in PPSSPP, against a slideshow through the stock
    EBOOT before the fixes in section 3.

## 6. Limits of the stock EBOOT path for large games

- Canvas, Shader and Mesh are stubs; shader-based effects are not drawn.
- Textures are limited to power-of-two sizes up to 512, so large atlases have to be split.
- Only two audio voices.
- Every scaled or rotated draw costs a `resize` of the whole sheet plus a clip, so a scene that animates
  scale and rotation on every sprite (Balatro animates every card) pays this per draw. Expect this path to
  stay well below the native engine for that kind of game.

## 7. Not verified yet

- Balatro through the wrapper with the fixes of sections 3 and 4: the earlier attempt predates them, and
  no frame-rate number exists for the current state.
- Everything on real hardware (cache effects, memory limits, file I/O).
- 3DS timings: only the test mock was used.
- LuaJIT: lpp-vita already runs LuaJIT 2.1 (whether with JIT on is not confirmed); the other players are PUC Lua. Assessment and gated experiment in `PERFORMANCE_SPEC.md` section 3.

The decision-oriented summary is `PERFORMANCE_REPORT.md`. Next steps are in `PERFORMANCE_SPEC.md` (catalogue W1-W21) and `PERFORMANCE_PLAN.md` (phases).

## 8. Reproducing

```
lua5.1 tests/run_all.lua                       # all suites
lua5.1 tests/bench/frame_cost.lua              # synthetic frame, per backend
lua5.1 tests/bench/frame_cost.lua --check      # compare with the baseline
lua5.1 tests/bench/vm_cost.lua                 # per-call instruction cost
lua5.1 tests/bench/alloc_cost.lua              # per-call allocation
lua5.1 tests/bench/api_coverage.lua            # love.* functions a game calls vs. defined
```
