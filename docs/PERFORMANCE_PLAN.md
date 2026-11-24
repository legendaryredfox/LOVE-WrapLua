# Performance plan

Implements `PERFORMANCE_SPEC.md`. IDs refer to the catalogue there. Every task ends with: tests pass on
`lua5.1`, `lua5.4` and `luajit`; `tests/bench/frame_cost.lua --check` has no regression; the numbers go
in `Changelog.md`.

## Status, 2026-11-17 (before the native pivot)

Done, or done in part judging by the commit history (2.1 to 2.3 were not re-audited against their task text): 0.1, 0.2 (`frame_cost.lua` prints wall time per frame and the Lua runtime, `-joff` included), 0.3 (`api_coverage.lua` boots the runtime in `script.lua` order; checked against ten calls), 1.1, 1.2 (first same-scene number, `PERFORMANCE_FINDINGS.md` section 7), 2.1, 2.2 (font width cache, 3DS text), 2.3 (circle and ellipse point cache), 2.4 (the polygon cache snaps to the nearest pixel, so animated shapes hit it), 2.5, 2.6, 2b.1
(partial: plain blit measured, rotated blit not), 2b.2 (W25 as an opt-in; W24 already held at scale 1),
3.1 (OneLua; the PS3 draw path and the 3DS quad inset cache followed), 3.2, 3.4, 3.5, and from 3b.1 the pure-Lua stubs `shear`, `setLineStyle`/`setLineJoin`/`setPointSize`, `Font:hasGlyph`/`setFilter`/`setFallbacks` and `filesystem.mount`/`unmount` (directories only). Decided against: 3.3.
Not started: 1.3, 2b.3, 3b.2 to 3b.6, 3b.1 particle curves (W45), 4.*, 5.*.

**Gate 1 is decided (2026-11-17):** Balatro `SELECTING_HAND` through OneLua stays near 1.1 fps (draw 372 ms, update 105 ms
per step, all in the game's own Lua), against 15.6 to 16.4 fps for the native engine. The project moved the PSP target to a
native backend (4.3, W17); the OneLua path keeps Phases 2 and 3 only.

## Status, 2026-11-24 (native PSP backend)

Phase 4.3 and 4.4 are done in the repository: `native/` (C engine on sceGu, Lua 5.1.5), `LOVE-WrapLua/PSPNative/` (the `love.*`
layer), `tools/lovepsp.lua` (build, package, manifest). 4.4 has real canvas, Mesh, ImageFont, ImageData, `captureScreenshot` and
MP3 on `sceAudiocodec`; Shader stays a stub and stencil is only what the engine does for canvas alpha. Measured in PPSSPP, Balatro
`SELECTING_HAND` (emulator figures, no hardware yet):

| Date | Change | fps |
|---|---|---|
| 11-17 | native baseline, audio off | 16.4 |
| 11-21 | MP3 on the Media Engine, tight mixer loop (audio on) | 16.2 |
| 11-22 | UI canvas cache in strips, shadows off | 17.7 to 18.0 |
| 11-22 | signature walk skipped on alternate frames (`walk2`) | 18.6 |
| 11-23 | `Moveable:move` and `move_*` in C | 25.6 |
| 11-23 | UI cache signature walk in C | 27.1 |
| 11-23 | round-robin update gate in C | 28.2 |
| 11-23 | `Game:update` moveable loops in C | 29.4 |
| 11-23 | `prep_draw` and `translate_container` in C | 31.8 |

The 30 fps working target of the native phase is met (update 14.6 ms, draw 17.1 ms). Details and the traps found on the way are in
`NATIVE_PSP_AUDIT.md`. Open on this path, in order:

1. Blind-select and overlay screenshot diffs with the UI cache on and off; the canvas test game is `tests/games/canvas`.
2. The Balatro-shaped C is now in `native/src/balatro/` behind `GAME=balatro` and registers as `native.balatro` (2026-11-24); the UI
   cache itself still lives in `balatro_psp/psp/opt.lua`. Left: decide whether the cache's engine half (atlas, strip blits) becomes
   a generic `native` feature.
3. Decide whether shadows off is the PSP default (about 2.7 ms by itself).
4. Hardware test: nothing here ran on a real PSP, and PPSSPP timing is not hardware timing.
5. Native `hash`, joystick/thread/filesystem from the shared modules, a PSP-native row in `core/capabilities.lua`.

## Status of the OneLua and other backends, 2026-11-17

Done, or done in part judging by the commit history (2.1 to 2.3 were not re-audited against their task text): 0.1, 0.2 (`frame_cost.lua` prints wall time per frame and the Lua runtime, `-joff` included), 0.3 (`api_coverage.lua` boots the runtime in `script.lua` order; checked against ten calls), 1.1, 1.2 (first same-scene number, `PERFORMANCE_FINDINGS.md` section 7), 2.1, 2.2 (font width cache, 3DS text), 2.3 (circle and ellipse point cache), 2.4 (the polygon cache snaps to the nearest pixel, so animated shapes hit it), 2.5, 2.6, 2b.1
(partial: plain blit measured, rotated blit not), 2b.2 (W25 as an opt-in; W24 already held at scale 1),
3.1 (OneLua; the PS3 draw path and the 3DS quad inset cache followed), 3.2, 3.4, 3.5, and from 3b.1 the pure-Lua stubs `shear`, `setLineStyle`/`setLineJoin`/`setPointSize`, `Font:hasGlyph`/`setFilter`/`setFallbacks` and `filesystem.mount`/`unmount` (directories only). Decided against: 3.3.
Not started: 1.3, 2b.3, 3b.2 to 3b.6, 3b.1 particle curves (W45), 4.1, 4.2, 5.*. Since 11-17 also: 3b.4 partial (3DS text input, Vita vibration, Vita and native PSP screenshot).

## Phase 0 — baseline and guard (1 day)
| # | Task | Items | Done when |
|---|---|---|---|
| 0.1 | Add `frame_cost.lua --check`, `vm_cost.lua`, `alloc_cost.lua` to the CI workflow with thresholds | W15 | CI fails on a 10 % regression |
| 0.2 | Add wall-time per synthetic frame to the bench (printed, not asserted) and `-joff` runs for LuaJIT | W19 | numbers visible per Lua runtime |
| 0.3 | Refine `api_coverage.lua` module loading so the "missing" list is trustworthy | W16 | list matches a manual check of 10 calls |

## Phase 1 — measure the real game through the wrapper (1-2 days)
| # | Task | Items | Done when |
|---|---|---|---|
| 1.1 | Build the reference game on `perf/wrapper-hot-paths` (OneLua PSP) and boot it in PPSSPP; list crashes, missing calls and visual gaps | W18 | table of failures with call names |
| 1.2 | Measure frame rate in the same scene as the native engine (selecting-hand state, fixed seed) and the split into update vs draw | W18 | number in `PERFORMANCE_FINDINGS.md` |
| 1.3 | Count draws, transform operations and scaled/rotated draws per frame to confirm the synthetic frame mix | W1, W5 | mix within 20 % of the synthetic frame, else update `frame_cost.lua` |

**Gate 1:** if the game is under 5 fps through OneLua after Phase 2, the stock-EBOOT route is judged
insufficient for this class of game and W17 becomes the priority (decision with the maintainer).

## Phase 2 — cheap, safe wins (2-3 days)
Order by risk, each with an A/B in the bench.
| # | Task | Items |
|---|---|---|
| 2.1 | Early returns in state setters; incremental transform flatten; skip `applyScissor` when idle | W4, W3 |
| 2.2 | Text: width/line-break cache per (font, string); 3DS `setColor` memo | W10, W9 |
| 2.3 | PS3 circle/ellipse/polygon point cache and convex fill | W8 |
| 2.4 | Polygon cache hardening (size bound, rounded rectangles, circle/ellipse) with hit/miss counters | W7 |
| 2.5 | Capability detection in `love._backend` | W14 |
| 2.6 | Filesystem manifest cache | W13 |

Target after Phase 2: PSP synthetic frame at most 100k instructions (R5), PS3 under 150k.

## Phase 2b — OneLua player findings (1-2 days, can run beside Phase 2)
| # | Task | Items | Done when |
|---|---|---|---|
| 2b.1 | Probe in PPSSPP: rotated and scaled blit time against sheet width and quad size; fix the cost model in `PERFORMANCE_FINDINGS.md` | W22 | table of ms per 100 draws |
| 2b.2 | Skip resize and clip for axis-aligned, scale-1 draws; quantise tiny angles behind an option | W24, W25 | rotated-card scene faster on the probe, tests pass |
| 2b.3 | Investigate per-quad images: does `image.new`, a screen capture or any API create an image from a region? If not, write the build-time splitter | W23 | decision recorded; prototype if possible |

**Gate 2b:** W23/W26 only proceed if 2b.1 shows the column cost is at least 25 % of a rotated draw.

## Phase 3 — draw path (3-5 days)
| # | Task | Items |
|---|---|---|
| 3.1 | Specialised `draw`/quad draw per Image/Quad with closed-over state | W1 |
| 3.2 | lpp-vita direct mapping to `drawImageExtended` / `vita2d_draw_texture_part_scale_rotate` (the mapping existed; the Lua around it was trimmed, 357 to 192 instructions) | W2 |
| 3.3 | Same-state draw batching with a replay loop; flush on blend, scissor, font or colour change (decided against for OneLua, see `PERFORMANCE_FINDINGS.md` 3.3) | W5 |
| 3.4 | `SpriteBatch`/`Text`/`ParticleSystem` compact arrays | W11 |
| 3.5 | Main loop allocations and catch-up skip | W12 |

Target: draw path at most 120 instructions per draw on OneLua/PSP; lpp-vita at most 200.

## Phase 3b — stubbed functions (parallel, ordered by effort)
Each task replaces a stub by real behaviour, updates the matching row of `Implemented.md` (stub/tracked to a
check mark with the backend noted) and adds a test; behaviour that needs the native backend is deferred to
Phase 4.
| # | Task | Items |
|---|---|---|
| 3b.1 | Pure-Lua stubs: `shear`, `setPointSize`/`setLineStyle`/`setLineJoin`, `Font:hasGlyph`/`setFallbacks`/`setFilter`, `filesystem.mount`/`unmount`, particle curves | W38, W39, W40, W42, W45 |
| 3b.2 | Callbacks: `lowmemory` (memory guard), `focus`/`visible` where the SDK reports it, `wheelmoved` | W37, W28 |
| 3b.3 | Scissor on Vita OneLua and PS3 (software reject), blend modes where the SDK has them (`blitadd`/`blitsub`, lpp-vita, citro3d) | W36, W35 |
| 3b.4 | Text input on 3DS (`Keyboard.show`); vibration where exposed; screenshot call per SDK and a visual-regression helper | W41, W43, W44 |
| 3b.5 | Known-shader approximation table with one-time log for unknown shaders | W33 |
| 3b.6 | Canvas Lua fallback (record and replay), real canvas on lpp-vita via the small upstream patch | W31 |

## Phase 4 — structural (optional, after Gate 1)
| # | Task | Items |
|---|---|---|
| 4.1 | Deferred layer-sorted draw list behind a `love._backend` flag, off by default | W6 |
| 4.2 | API gaps by frequency from the coverage list | W16 |
| 4.4 | With the native backend: real canvas (render to texture), mesh, stencil, shader approximations that run on the GPU, hardware screenshot | W31, W32, W33, W34 |
| 4.3 | Native PSP backend: package the native engine and its LÖVE layer as an alternative runtime that passes the shared test contract. Sub-steps: (a) define the native API boundary, (b) port `graphics_psp` calls onto it, (c) tiles for textures above 512, (d) font path, (e) run the full test suite plus the reference game | W17 |

## Phase 5 — LuaJIT experiment (gated, parallel to Phase 2-3)
| # | Task | Items | Gate |
|---|---|---|---|
| 5.1 | Confirm in the lpp-vita sources/build what its LuaJIT runs and whether JIT is on; run the bench there | W20 | informs 5.2 |
| 5.2 | Build an interpreter-only LuaJIT for ARM and compare against PUC Lua on the synthetic frame (emulator or device) | W21 | at least 15 % |
| 5.3 | If 5.2 passes: prototype a custom lpp-3ds build and document how to reproduce it | W21 | at least 15 % on 3DS |
| 5.4 | PSP-native: follow the Balatro project's plan 2.9b | W21 | at least 15 % |
| 5.4b | Lua 5.4 (`LUA_32BITS`) on the native backend: same micro-benchmark and rule | W30 | at least 15 % |
| 5.5 | Record the outcome, pass or fail, in `PERFORMANCE_FINDINGS.md` | W21 | always |

PS3 and PSP/OneLua are not in this phase: no feasible LuaJIT player (see spec section 3).

## Estimates and order
Phase 0 → 1 → 2 → 3 is the main line; Phase 4 and Phase 5 depend on the gates. Expected effect of Phases
2-3 on the synthetic PSP frame: 122k to roughly 85-100k instructions (about 25-33 ms at 0.3 µs), which is
an estimate until measured on the reference game (Phase 1). A native backend (W17) is the only item
expected to change the class of result; everything else trims the existing path.

## Licensing checkpoint
Before distributing anything that replaces or derives from the OneLua player (W17, the W23 splitter if it ships
a runtime), check the ONElua licence and the licences of every library it embeds. Until then the decompiled
output stays local and is used only to understand behaviour.

## Decisions needed from the maintainer
- Push or open a PR for `fix/onelua-no-copyscale` and `perf/wrapper-hot-paths`.
- Whether the native PSP backend (W17) should live in this repository or next to it.
- Testing on real hardware and which devices are available.
