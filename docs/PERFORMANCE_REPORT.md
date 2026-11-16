# Report: performance of the wrapper and analysis of the OneLua player

Date of the measurements: 2026-11-06. Detailed numbers are in `PERFORMANCE_FINDINGS.md`; the catalogue of work
is `PERFORMANCE_SPEC.md` and the schedule is `PERFORMANCE_PLAN.md`.

## 1. Summary

- The shared graphics layer was slow on every backend. A synthetic frame the size of a heavy LÖVE scene (213
  transform operations, 168 colour changes, 124 draws, 54 polygon fills, 45 prints) cost 243k VM instructions
  on PSP. After the changes on branch `perf/wrapper-hot-paths` it costs 122k (-50 %); OneLua 223k to 102k,
  lpp-vita 237k to 115k, PS3 344k to 195k. Garbage per frame fell from about 29 KB to about 2 KB. These are
  mock-based instruction counts, not frame rates on a console.
- Scaled, mirrored and rotated draws did not work on the stock PSP player (no `image.copyscale`). Branch
  `fix/onelua-no-copyscale` makes them work with the stock `EBOOT.PBP` (issue #3). `draw(image, quad, ...)` also
  dropped its `oy` argument.
- The stock OneLua PSP player is the main remaining limit. Decompiling it showed that every rotated blit is
  cut into 64-pixel columns, each with its own allocation and GPU draw call. With a 512-pixel sheet that is 8
  per rotated card.
- LuaJIT is not a lever for most backends: lpp-vita already uses it; the other players are PUC Lua and cannot
  be replaced without source.
- A native PSP backend (W17) is the only item expected to change the class of result; a native engine that
  does this reaches about 14 fps on a full Balatro scene in PPSSPP, where the stock path was a slideshow.

## 2. Method

- Counted VM instructions and bytes allocated per `love.graphics` call and per synthetic frame with a count
  hook on the test mocks (`tests/bench/`), using Lua 5.1; the rest of the suites run on 5.1, 5.3, 5.4 and
  LuaJIT.
- Cost model from the PSP player in PPSSPP: about 3 million VM instructions per second. PPSSPP timing is
  deterministic but does not model the PSP's 16 KB data cache, so real devices may differ.
- Probed the stock EBOOT API with small scripts in PPSSPP (`copyscale`, `resize`, `clip`, `center`).
- Disassembled and decompiled the EBOOT's PRX: `psp-objdump` for the library tables; Ghidra 12.1.3 with the
  `ghidra-allegrex` extension for decompilation. The REA tool opens the file but its Ghidra provider refuses
  PRX images, so Ghidra was used directly.
- Studied other open-source players and engines for patterns (batching, throttling, render-to-texture).
  Unlicensed or commercial sources were used for study only.

## 3. Findings that matter for the wrapper

1. **Polygon fill was the largest single cost** (about 60 % of the synthetic frame): a Lua scanline rasteriser
   ran on every call. Merged rectangles with a cache keyed by the transform fingerprint removed most of it.
2. **`setColor` and the transform stack allocated on every call.** In-place update, memoised native colours
   and recycled stack levels brought `setColor` from 92 to 37 instructions and from 352 to 0 bytes.
3. **Rotation cost on the stock player is a function of image width.** The routine at `0x4fbe8` loops over
   64-pixel columns (`ceil(width / 64)` GPU draws plus one 80-byte allocation each). Because the wrapper turns
   the whole scaled copy of a sheet, a small card on a 512 px sheet pays for the full sheet width. Work item W23
   (rotate small images) and W24/W25 follow from this.
4. **The unrotated blit takes a separate path** in the player; avoiding resize and clip for axis-aligned,
   unscaled draws keeps it on the cheap path.
5. **GC is not the bottleneck.** With the reference game, GC cost was about 0.2 ms per frame and the heap
   settled at 6.5-7.5 MB in a 90 000-frame run. No collector tuning is needed; a memory guard is.
6. **Throttling at game level gave the biggest game-side gains** (round-robin updates, a time-based cursor
   collision gate). They are not wrapper code, but every heavy OneLua game benefits (W27).
7. **Several graphics calls are stubs or only tracked**: canvas, mesh, shader, stencil, shear, line style and
   join, point size, screenshot, font fallbacks, several callbacks, scissor and blend modes on some backends.
   Canvas matters for speed: caching static UI in a canvas removes hundreds of draws per frame. The full list
   with a plan to implement each one is in the spec, section 2.8 (W31-W46).

## 4. What was not measured

- The reference game through the wrapper after the fixes. This is the next step (spec W18, plan phase 1).
- Anything on real hardware, and 3DS timings (only the test mock).
- Whether lpp-vita runs LuaJIT with the JIT on.
- Per-column rotation cost in PPSSPP (planned probe W22).

## 5. Recommendations

1. Run the reference game through the wrapper and record frame rate and missing calls (plan phase 1).
2. Do the cheap wrapper wins of phase 2 and the rotated-draw probe of phase 2b; proceed with per-quad images
   only if the probe shows the column cost is at least 25 % of a rotated draw.
3. Implement the pure-Lua stubs and the callbacks (phase 3b) in parallel, since they are small and improve
   compatibility.
4. Decide after the gates whether to build the native PSP backend (W17); it is the route to canvas, mesh,
   stencil and GPU-side effects.
5. Keep LuaJIT and Lua 5.4 as gated experiments (at least 15 % on the synthetic frame) and do not plan around
   them.

## 6. Progress, 2026-11-16

Work done after the first report, all on the test mocks (VM instruction counts and bytes, Lua 5.1 count hook;
suites green on Lua 5.1, 5.4 and LuaJIT). Nothing was run in PPSSPP or on a device; the reference game has
still not been run through the wrapper (plan phase 1).

Synthetic frame, VM instructions (first report in brackets):

| backend | first report | now |
|---|---|---|
| PSP | 122k | 99.8k |
| OneLua | 102k | 96.0k |
| lpp-vita | 115k | 97.1k |
| PS3 | 195k | 196.2k |

What changed, by plan item (details in `Changelog.md`):

| plan | change | measured effect |
|---|---|---|
| 2b.2 / W25 | `lv1luaconf.rotatesnap`: small turns drawn upright (OneLua, opt-in) | skips pivot, clip and trig on those draws; not visible in the synthetic frame, which has no small angles |
| 2.4 / W7 | rounded `rectangle` (`rx`, `ry` were ignored), polygon cache bounded at 512 rectangles, hit/miss counters | synthetic frame 54 hits, 0 misses |
| 2.6 / W13 | `love.filesystem` caches path metadata and listings (game dir for good, save dir until the wrapper writes) | one native stat per path instead of two to four per call, at about 11 ms each in PPSSPP |
| 3.1 / W1 | OneLua draw: metatable check, cached quad inset, scale-1 short path, remembered rotation | PSP quad draw 216 to 145 instr, image draw 185 to 153 |
| 3.1 | scaled path (`clipBlit`) trimmed | PSP scaled quad 389 to 352 |
| 3.2 / W2 | lpp-vita draw: same Lua trimming (the native mapping already existed) | quad draw 357 to 192 instr, frame 115k to 97k |
| 2.5 / W14 | `OneLua/native.lua` probes the SDK once, `love._backend.native` | no per-draw `type()` tests; builds missing `blittint` or scaling no longer raise |
| 3.4 / W11 | `SpriteBatch` parallel arrays, pooled particles, replay closures built once | 200 `add`: 81 KB to 192 B; 200-particle update: 4.2 KB to 88 B; instruction counts rise 15 to 28% |
| 3.5 / W12 | per-frame input tables reused; optional `lv1luaconf.frameskip` | under 100 B per `updatecontrols` frame in the mock |

Decided against: deferred draw batching on OneLua (plan 3.3 / W5). The calls it would save were measured under
11 microseconds each, below the probe's resolution, and the flush hooks it needs touch every other draw call;
see `PERFORMANCE_FINDINGS.md` 3.3.

Bench tools added: `tests/bench/batch_cost.lua`; `frame_cost.lua` now prints polygon cache hits and misses.
New suites: `polygon_cache_test`, `fs_cache_test`, `draw_fast_test`, `lppvita_draw_fast_test`,
`native_probe_test`, `batch_compact_test`, `mainloop_test`.

Still open:

- PS3 is the heaviest backend (196k per frame, 316 instr per image draw) and has had none of the draw-path
  work.
- 3DS `draw` still calls `getViewport` per draw; the 3DS frame is not in the benchmark (draws only inside a
  GPU frame).
- `event.pump` and `keyboard` were not audited for per-frame garbage.
- Particle curves (W45) were left out; they would build on the compact arrays.
- Whether a Lua-to-Lua build step (a transpiler that precomputes static transforms and quad draws) or a custom
  interpreter is worth building is undecided. The numbers so far say the wrapper's own Lua costs about as much
  as the native blit (about 64 microseconds of VM time per draw against about 33 to 45 microseconds for the
  blit), which argues for measuring the reference game first (phase 1, Gate 1) before choosing.
