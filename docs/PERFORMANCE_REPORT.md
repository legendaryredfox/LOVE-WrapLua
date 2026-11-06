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

## 6. Licensing

The OneLua player's licence has not been checked. It must be checked before distributing anything that
replaces or derives from the player (W17 and any build-time tool that ships player code). Decompiled output is
kept local and used to understand behaviour only.
