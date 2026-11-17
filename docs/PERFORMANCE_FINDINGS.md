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

### 2b.1 probe: native blit cost in PPSSPP (partial, 2026-11-16)

A script on the stock EBOOT draws N blits per frame, then `screen.flip()`; the frame time minus the empty
frame (16.7 ms, vsync) gives the cost. Frame times land on vblank multiples, so anything under about
1.1 ms per 100 calls cannot be resolved.

| operation (512x512 and 64x64 sheets) | ms per 100 calls |
|---|---|
| sub-rect `blit` 32x48 (512 sheet and 64 sheet, same) | 4.5 |
| whole `blit` of a 64x64 image | 3.3 |
| whole `blit` of the 512x512 sheet | 4.2 |
| `screen.clip(x, y, w, h)` | below 1.1 |
| `image.resize(img, w, h)` | below 1.1 |
| `image.rotate(img, deg)` | below 1.1 |

- A native blit costs about 33 to 45 microseconds and does not depend on the sheet size, so the column-cost
  model for W26 is not supported by the plain blit. The rotated blit and the full scaled path were not
  measured: the scaled-path probe resized the 512 sheet to 1024 (above the 512 texture limit) and stalled.
- `clip`, `resize` and `rotate` each cost under about 11 microseconds, so the six extra calls of a scaled
  draw are at most about 60 microseconds beside the blit, and the wrapper's own Lua (about 213 VM
  instructions, roughly 64 microseconds at 0.3 microseconds each) costs as much as the blit itself.
- Gate 2b (W23/W26 proceed only if the column cost is at least 25% of a rotated draw) is not met by this
  data; the rotated blit still needs its own probe with sheets up to 512 and scales that stay inside it.

### 3.3 decision: no deferred draw batching on OneLua (2026-11-16)

What batching could save on a stock-EBOOT scaled draw is the native call pair around it: `image.resize` in and
out, and the `screen.clip` set and restore, for consecutive draws of one sheet at one size. The 2b.1 probe
measured each of those at under 11 microseconds, below what the probe can resolve (about 1.1 ms per 100
calls), so the best case is about 33 microseconds per scaled draw, roughly 1 ms on the synthetic frame (33
scaled draws), about 3%. The cost side is large: a deferred list needs a flush hook in every other draw
(rectangle, line, polygon, print, plain blits) to keep draw order, the recording itself costs about as many VM
instructions as the per-draw state work it replaces, and a sheet left resized between draws is shared with
every Image and Quad cut from it. So no batching code was written. Reopen it if a probe that resolves single
calls shows `resize` or `clip` above about 30 microseconds on a real PSP.

What 3.1 did instead is in the changelog: the per-draw VM work, which is the part that is measurable.

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

- Balatro at the same scene as the native engine (`SELECTING_HAND`, fixed seed): the autoplay scripts are wired
  only into the native boot, not the OneLua `psp/main.lua`. See the 2026-11-17 run below for the title screen.
- Everything on real hardware (cache effects, memory limits, file I/O).
- 3DS timings: only the test mock was used.
- LuaJIT: lpp-vita already runs LuaJIT 2.1 (whether with JIT on is not confirmed); the other players are PUC Lua. Assessment and gated experiment in `PERFORMANCE_SPEC.md` section 3.

The decision-oriented summary is `PERFORMANCE_REPORT.md`. Next steps are in `PERFORMANCE_SPEC.md` (catalogue W1-W21) and `PERFORMANCE_PLAN.md` (phases).

### Balatro through the wrapper, 2026-11-17 (title screen only)

Build `tools/build.sh` in `balatro_psp` against wrapper master, run in PPSSPP (RetroArch core, uncapped, no
audio). The earlier attempt died on frame 1; this one runs 600 updates:

- First crash fixed: `Canvas` had no `getPixelWidth` / `getPixelHeight` / `getPixelDimensions`.
- Boot to first `love.draw`: about 7 s (emulated clock).
- Title scene (cards flying in): about 8.6 draws per second in the first second, falling to about 1.4 per
  second at 50 s; the `love.update` call time grows from about 23 ms to about 150 ms over the same period.
  The growth is the scene, not the wrapper: Balatro's splash vortex queues 200 `make_splash_card` events by
  game time, and the card count (0 at 10 s, 57 at 57 s on the emulated clock) tracks the update time (19 ms
  with 1 card, 143 ms with 57). `psp/main.lua` with `AUTOPLAY=1` now skips the splash for benchmarks.
- Visual gaps: no background or shader, white rectangles around rotated cards (the whole-copy rotation of the
  OneLua draw), so the scene is not faithful.

### Balatro blind-select scene, 2026-11-17

`AUTOPLAY=1 tools/build.sh` wires the native boot's `autoplay.lua` into the OneLua boot (`psp/main.lua`) and logs
the cost every 3 s (`BENCH` lines: update and draw time, rates, heap, polygon cache, time inside native
calls; `PROFILE=1` adds a sampling profile of `love.draw`). The emulator runs this at about 0.06 of real
time, so a run only reaches the blind select screen (state 7, 53 cards) in the time available; the
`SELECTING_HAND` number is still missing.

- Second crash fixed: coloured text (`{color, "string", ...}`) raised `bad argument #2 to 'textwidth'` in
  `love.load`; `print`, `printf`, `Font` and `Text` now accept it.
- Blind select as measured first: `love.draw` 1090 ms (0.6 draws per second), `love.update` 97 ms.
  Time inside native calls was about 120 ms per 3 s window, so the draw was Lua VM time. The sampling
  profile put 61 to 67% of the draw in `core/polyfill.lua polygonRuns`, called for Balatro's pixelated UI
  rectangles (about 40 polygon fills and 1300 rectangles per draw).
- Cause: the polygon run cache was keyed on the sub-pixel part of the shape's origin as well, and an animated UI
  drifts by fractions of a pixel every frame. All 80 lookups per window missed (`frac`, never `sum` or
  `scale`). The origin now lands on the nearest whole pixel and the runs are kept relative to it, so every
  lookup hits. A polygon drawn at a fractional offset sits up to half a pixel from where it sat before; the
  vertices' own fractions are unchanged.
- After: `love.draw` about 270 ms (1.2 draws per second), 4x faster, cache 160 hits and 0 misses per window.
  The scene is still slow: what remains is 53 cards plus the UI, now spread over the image draw and the
  remaining polygon work.

### Balatro SELECTING_HAND through the wrapper, 2026-11-17

Same harness, after the polygon cache change, 42 consecutive 3 s windows (about 130 s of emulated clock) in the
scene the native engine reports 15.6 fps for (seed `BENCH`, first hand, 53 cards, no tutorial):

| | wrapper (OneLua on PSP) | native engine |
|---|---|---|
| `love.draw` | 372 ms, 1.07 draws per second | |
| `love.update` | 105.5 ms, 5.3 calls per second | |
| frame rate | about 1.1 fps | 15.6 fps |

- Inside native calls the draw spends about 220 ms per 3 s window (4500 `draw.fillrect`, 285 `screen.print`
  calls): about 7% of the time. The rest is the Lua VM.
- The polygon cache hits on every lookup (150 per window). `love.update` alone costs 105 ms per 1/60 s step, so
  even a free `love.draw` would cap the game at about 9.5 steps per second: the game's own logic, run by
  OneLua's interpreter, is the larger problem now. Whether that is the interpreter, soft-float on the PSP's
  single-precision FPU, or wrapper calls inside `love.update` is not measured.
- Gate 1 (is pure Lua on OneLua viable for this game): at about 1.1 fps against 15.6 fps the answer for
  Balatro is no, with a 14x gap that no single hotspot closes. The wrapper's target stays games that do far
  less per frame.

### Where `love.update` spends its time in SELECTING_HAND, 2026-11-17

A sampling profile of `love.update` (a debug hook every 10000 VM instructions, 30 updates in `SELECTING_HAND`, 53
cards; PPSSPP through RetroArch; the hook makes each update about 60% slower, 171 ms against 105 ms). Reproduce
with `AUTOPLAY=1 PROFILE=update tools/build.sh` in the Balatro harness. 390 samples, so 3.9M VM instructions for
30 updates: about 130k instructions per update, which at 105 ms is about 1.2M instructions per second, well under
the 3M the cost model assumes.

| Function (game source) | Self | Inclusive |
|---|---|---|
| `Moveable:move` (`engine/moveable.lua:278`) | 17 to 21% | 56 to 59% |
| `Node:update` (`engine/node.lua:143`) | 15% | 21 to 23% |
| `Controller:update` (`engine/controller.lua:186` / `:954`) | 2% | 23% |
| `Card:update` (`card.lua:4267`) | 5% | 14 to 15% |
| `Moveable:move_xy` / `move_r` / `move_wh` / `move_scale` and the other `moveable.lua` helpers | 3 to 9% each | 4 to 10% each |

- No function of the wrapper appears in the top 22 self entries: the only wrapper frames are the loop itself
  (`timestep.lua`, `whileloop.lua`). `love.update` is the game's own logic, run by OneLua's interpreter.
- Moveable physics (position, scale, rotation and size springs, per node, per update) is more than half of it. 53
  cards plus the UI tree are about 500 moveables, so it is about 250 instructions per moveable per update.
- Nothing in this profile gives the wrapper a lever. A cheaper `love.update` has to come from the game side
  (updating fewer moveables per step, skipping settled ones) or from a faster VM, which is Gate 1.

## 8. Reproducing

```
lua5.1 tests/run_all.lua                       # all suites
lua5.1 tests/bench/frame_cost.lua              # synthetic frame, per backend
lua5.1 tests/bench/frame_cost.lua --check      # compare with the baseline
lua5.1 tests/bench/vm_cost.lua                 # per-call instruction cost
lua5.1 tests/bench/alloc_cost.lua              # per-call allocation
lua5.1 tests/bench/api_coverage.lua            # love.* functions a game calls vs. defined
```
