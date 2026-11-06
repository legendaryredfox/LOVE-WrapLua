# Performance spec

Scope: performance of the wrapper (`LOVE-WrapLua/`) on PSP (OneLua), Vita (OneLua and lpp-vita), 3DS (lpp-3ds)
and PS3. Measurements and what is already done are in `PERFORMANCE_FINDINGS.md`; the order of work is in
`PERFORMANCE_PLAN.md`.

## 1. Goal and requirements

Goal: a LÖVE 11 game with a heavy draw load (Balatro is the reference: about 150 draw calls, 200 transform
operations, 170 colour changes, 50 polygon fills and 45 text draws per frame) runs at a playable frame rate
through the wrapper on every backend, without changing the game's code.

| ID | Requirement |
|---|---|
| R1 | The public API keeps the signature and return values of the LÖVE 11 function it replaces. |
| R2 | The wrapper runs on Lua 5.1, 5.3, 5.4 and LuaJIT (existing rule); nothing in this spec may break one of them. |
| R3 | Every optimisation is measured by `tests/bench/` (instructions and bytes per call, synthetic frame) before and after, and the result is recorded in `Changelog.md`. |
| R4 | No visual change unless a test documents it (`tests/*_test.lua` or a pixel-exact mock expectation). |
| R5 | A per-frame budget: a synthetic Balatro-sized frame costs at most 100k VM instructions on PSP/OneLua and at most 60k garbage bytes over ten frames. Current: 122k and about 2 KB per frame. |
| R6 | No new global names (`tests/globals_test.lua`). |
| R7 | Features that need an unavailable native API fall back and report it through `love._backend`; the wrapper must not crash on a stock EBOOT. |

Cost model: about 3 million VM instructions per second on PSP (0.3 µs each), so 100 instructions is about
30 µs. Garbage matters less than instructions (GC measured at about 0.2 ms per frame).

## 2. Catalogue

Columns: evidence, expected gain, effort (S/M/L), risk (B low, M medium, A high), backends. IDs `W*` are
new; the older C-numbers from the research notes are given in parentheses.

### 2.1 Draw path (all backends)
| ID | Item | Evidence | Gain | Effort | Risk |
|---|---|---|---|---|---|
| W1 (C1) | Specialise `draw` and quad draw per Image/Quad: precompute inset, blit function (colour/blend) and scale once, close over them; at most 120 instructions per draw on OneLua/PSP | `vm_profile`: `imagedraw` 124-150 instr, `texinset` 10, `psp/state.blitImage` 23 | about -30 % of draw cost | M | B |
| W2 (C2) | lpp-vita `draw` with quad: map to `Graphics.drawImageExtended` / `vita2d_draw_texture_part_scale_rotate` (scale and rotate on GPU) | 357 instr per call | about -40 % | M | B |
| W3 (C5) | `push/translate/pop` flatten incrementally and skip `applyScissor` when no scissor is active | `transform.lua`: 104 instr per 3 ops | about -30 % of transform cost | S | B |
| W4 (C6) | Early return in `setBlendMode`, `setLineWidth`, `setFont`, `setShader`, `setScissor` when unchanged | reading of `core/state.lua` | small | S | B |
| W5 | Batch consecutive `draw` calls of one image with the same state into one list and replay it with a tight loop (no per-call state checks) | `draw` fixed cost per call | -10 to -20 % of draw cost | M | M |
| W6 (C14) | Deferred, layer-sorted draw list: record commands in reused tables, sort by layer, replay; lets the wrapper group by texture/state and skip fully hidden draws | pattern from another Lua game studied locally | depends on the game | L | M |

### 2.2 Shapes and text
| ID | Item | Evidence | Gain | Effort | Risk |
|---|---|---|---|---|---|
| W7 | Polygon cache hardening: bound cache size, cache `rectangle("fill")` with rounded corners and `circle`/`ellipse` the same way, add hit/miss counters in the bench | polygon fill was about 60 % of the synthetic frame; now cached | keeps the -50 % stable for new shapes | S | B |
| W8 (C3) | PS3 `circle` / `ellipse` / `polygon("fill")`: cache points per (radius, segments), fast convex fill | 17 300 instr per circle | about -90 % on that call | S | B |
| W9 (C4) | 3DS: `setColor` memo like the PSP one, cache of text metrics for `print` | `setColor` 177, `print` 261 instr | about -50 % | S | B |
| W10 (C7) | `print`/`printf`: cache width and line breaks per (font, string); drop `gmatch` from the per-frame path | 72-261 instr per call | about -50 % on text | S | B |

### 2.3 Objects, loop, I/O
| ID | Item | Evidence | Gain | Effort | Risk |
|---|---|---|---|---|---|
| W11 (C8) | `SpriteBatch`, `Text`, `ParticleSystem`: compact arrays and a tight replay loop; native batch where the backend has one | `core/objects.lua` | depends on game | M | M |
| W12 (C9) | Main loop: fewer tables per frame in `timestep`, `event.pump`, `keyboard`; skip `love.draw` while the accumulator needs to catch up | `script.lua`, `core/timestep.lua` | 0.5-2 ms per frame | M | M |
| W13 (C10) | Filesystem: manifest cache for `getInfo`/`getDirectoryItems`; read each file once | about 11 ms per I/O call on OneLua/PPSSPP | removes stutters | S | B |
| W14 (C11) | Capability detection at start-up (`copyscale`, `clip`, `center`, `blitsprite`) choosing the fastest path per EBOOT, exposed in `love._backend` | stock EBOOT lacks `copyscale` | enables W1/W5 per backend | S | B |

### 2.4 Coverage, regression guard, native backend
| ID | Item | Evidence | Gain | Effort | Risk |
|---|---|---|---|---|---|
| W15 (C13) | Performance CI: `vm_cost.lua`, `alloc_cost.lua` and `frame_cost.lua --check` in the workflow with thresholds (for example `setColor` at most 60 instr) | tools exist, not in CI | prevents regressions | S | B |
| W16 (C15) | API coverage: refine `tests/bench/api_coverage.lua` (module loading is partial) and implement or stub missing calls by frequency (`love.thread.*`, `love.mouse.*`, `love.sound.newSoundData`, `love.image.newImageData`) | Balatro 64 of 78, another game 85 of 106 functions defined on PSP | fewer runtime errors | M | B |
| W17 (C12) | **Native PSP backend**: runtime that keeps the wrapper contract but draws through a native engine (sceGu): GPU scale/rotation/tint, tiles for textures above 512, TrueType fonts | native engine reaches about 14 fps on a Balatro scene in PPSSPP; stock EBOOT path is a slideshow | largest gain on PSP | L | M |
| W18 | Test the reference game through the wrapper with the fixes (PSP, OneLua) and record frame rate, missing calls and visual gaps | never measured since the fixes | decides the priority of W5/W6/W17 | M | B |

### 2.5 Interpreter choice (LuaJIT) — see section 3
| ID | Item | Gain | Effort | Risk |
|---|---|---|---|---|
| W19 | Keep the wrapper LuaJIT-clean: CI already runs LuaJIT; add `-joff` (interpreter only) to the benchmark runs and a trace-abort check (`-jv`) for the hot paths | keeps option open, catches slow constructs | S | B |
| W20 | lpp-vita: confirm what its LuaJIT runs (interpreter or JIT) and measure the wrapper there | tells the ceiling of the LuaJIT route | S | B |
| W21 | LuaJIT for other backends (custom player builds): 3DS, PS3, PSP-native | uncertain; gated | L | A |

### 2.6 Findings from decompiling the OneLua PSP player
Source: Ghidra 12.1.3 with `ghidra-allegrex` on the EBOOT's PRX (see `PERFORMANCE_FINDINGS.md` section 2). The
rotated-blit routine splits the image into 64-pixel columns and emits one `sceGuDrawArray` (4 vertices) plus
one 80-byte allocation per column.

| ID | Item | Evidence | Gain | Effort | Risk |
|---|---|---|---|---|---|
| W22 | **Cost probe for rotated and scaled draws on the stock EBOOT**: measure in PPSSPP the time of N rotated blits against sheet width (64, 128, 256, 512) and against quad size, to confirm the per-column cost and fix the model | decompiled routine: columns = `ceil(width / 64)` | decides W23/W24 | S | B |
| W23 | **Rotate small images, not whole sheets**: when a rotated quad is drawn, today the wrapper turns the whole scaled copy of the sheet, so a 512-wide sheet pays 8 column draws and 8 allocations for a 71 px card. Cache a per-quad image (or a per-sprite strip) so a rotated draw costs `ceil(quad width / 64)` columns. Needs a way to create an image from a region: check `image.new` (errors today), `screen` capture or pre-split assets at build time; if none exists, offer a build tool that emits one small file per rotated quad | decompiled routine; `Implemented.md` ("a rotated quad turns that whole copy") | up to -75 % of rotated-draw GPU/CPU cost for 512 sheets | M | M |
| W24 | **Keep the unrotated path hot**: avoid resize and clip when scale is 1 and the draw is axis-aligned (the unrotated blit takes a separate, cheaper routine); apply the same for mirrored draws with `fliph`/`flipv` | decompiled dispatch at the start of the routine | small, per draw | S | B |
| W25 | **Rotation quantisation**: round small angles (for example below 0.5 degree) to zero so the cheap path is used, and cache `sin/cos` for repeated angles; document it as an opt-in `love._backend` option because it changes pixels slightly | cost per rotated draw is a multiple of the unrotated one | depends on the game (Balatro rotates idle cards by small angles) | S | M |
| W26 | **Pre-rotated frame cache** for sprites that repeat the same angle (UI icons, coins): keep the rotated result as an image when the platform allows it | W23 prerequisite | high for repeated sprites | L | M |

### 2.7 Findings from the reference-game measurements that apply to the wrapper
| ID | Item | Evidence | Gain | Effort | Risk |
|---|---|---|---|---|---|
| W27 | **Time-based throttling helpers** (shared by games, not required by the wrapper): the game-side wins came from skipping work per frame at a time rate (cursor collision gate, round-robin updates with accumulated dt). Offer them as a small optional module (`love-wraplua/throttle.lua`) with documented limits, because every OneLua game pays the same ~0.3 µs per VM instruction | reference game: update time 58 ms to 34 ms with such techniques | helps any heavy game | S | B |
| W28 | **GC guidance and a memory guard**: GC cost is small (about 0.2 ms per frame) and the heap stabilised, so no collector tuning is needed; add a `lowmemory` callback driven by `collectgarbage("count")` against the backend limit (see W36) and a full collect on scene change helper | GC telemetry over 90 000 frames | stability | S | B |
| W29 | **Wall-time bench per backend** (printed next to instruction counts) so that LuaJIT, Lua 5.4 or native-backend experiments compare real time and not only VM instructions | LuaJIT / 5.4 discussion | enables the decisions in section 3 | S | B |
| W30 | **Lua 5.4 as an experiment for the native backend only** (the OneLua player is fixed at 5.1): build with `LUA_32BITS`; same decision rule as LuaJIT (at least 15 % on the synthetic frame, in PPSSPP) | pspdev already ships a Lua 5.4 port; wrapper tests already pass on 5.4 | uncertain | S | A |

### 2.8 Stubbed functions to implement
Stubs are callable and do nothing (`Implemented.md`, "stub"). "Tracked" values are stored and read back but
never reach the hardware. Each item below turns one of them into real behaviour, in the order of benefit.
`Native` means it needs the native PSP backend (W17), a platform patch, or an SDK call that the stock player
does not expose.

| ID | Stub / tracked | Where | How | Perf relevance | Effort |
|---|---|---|---|---|---|
| W31 | `newCanvas`/`setCanvas`/`renderTo` | all backends | Native: PSP render-to-texture (sceGu draw buffer swap), lpp-vita `vita2d` render target (small upstream patch), PS3 tiny3D scene-to-texture. Lua fallback: record the commands of a canvas and replay them when it is drawn (no GPU gain) | **high**: caching static UI in a canvas removes hundreds of draws per frame | L |
| W32 | `newMesh`/`Mesh:draw` | all | Native only (arbitrary vertices): `sceGuDrawArray`, `vita2d` vertices, tiny3D vertex arrays. Lua fallback: textured triangle fan for convex meshes through quads | medium (batching of custom geometry) | L |
| W33 | `newShader`/`setShader` | all | Native only. A table of known effect names mapped to cheap approximations (tint, additive blend, vertex colour) so games do not draw garbage; unknown shaders keep the current no-op and log once | low for speed, high for correctness | M |
| W34 | `stencil`, `setStencilTest` | all | Native: GU stencil. Lua fallback: scissor rectangle when the stencil is a rectangle | low | M |
| W35 | Blend modes tracked on OneLua/Vita, lpp-vita, 3DS | `setBlendMode` | Use `image.blitadd`/`blitsub` where they exist (PSP has them), `Graphics` blend flags in lpp-vita if exposed, citro3d blend in lpp-3ds | low | M |
| W36 | Scissor tracked on Vita OneLua and PS3 | `setScissor` | Software reject as lpp-vita does (skip draws fully outside), PS3 tiny3D scissor if exposed | skipping hidden draws is a perf win | S |
| W37 | `love.lowmemory`, `focus`, `visible`, `resize`, `wheelmoved` callbacks | all | `lowmemory` from the memory guard (W28); `focus`/`visible` from system suspend/resume events where the SDK reports them; `wheelmoved` from triggers or touch scroll; `resize` never fires (fixed screens) and stays documented | low | S |
| W38 | `shear` | transform stack | Add a shear term to the affine level for shapes, lines and text (computed in Lua, no native call); images keep the documented limit | none | S |
| W39 | `setLineStyle`, `setLineJoin`, `setPointSize` | all | `setPointSize` via filled squares; `rough` vs `smooth` as a no-op with a log; line joins `miter`/`bevel` for thick polylines in Lua | none | S |
| W40 | `Font:hasGlyph`, `setFallbacks`, `setFilter` | all | `hasGlyph`: codepoint range check per backend; fallbacks: draw per glyph with the first font that has it (cached per string, see W10); `setFilter`: store and apply on TTF where the SDK allows | none | S |
| W41 | `love.keyboard.setTextInput` / `textinput` on PS3 and 3DS | PS3, 3DS | 3DS: lpp-3ds `Keyboard.show` exists; PS3: on-screen keyboard through the system utility if the player exposes it, else keep stub | none | M |
| W42 | `love.filesystem.mount`/`unmount` | all | Virtual path prefix table consulted by `read`/`getInfo`/`getDirectoryItems` (pure Lua, ties into the W13 manifest cache) | none | S |
| W43 | `Joystick:setVibration` and `isVibrationSupported` | PS3, Vita | PS3 pad rumble and Vita via the player if exposed; otherwise keep `false` | none | S |
| W44 | `love.graphics.captureScreenshot` | all | Native screenshot call per SDK (`screen.save` on OneLua if present, `vita2d_save`, `tiny3D` buffer dump); also enables visual regression tests (the reference project has the same gap) | tooling | M |
| W45 | Particle system curves (size, colour, rotation are accepted and ignored) | all | Evaluate the curves in the emitter loop; keep the compact-array replay of W11 | none | M |
| W46 | Audio effects and listener API (`isEffectsSupported`, listener) | all | Keep `false`; only revisit if the native backend gets hardware audio | none | L |

## 3. LuaJIT assessment

The wrapper does not control its interpreter: it is a Lua library loaded by a prebuilt player on every
backend. Using LuaJIT therefore means a player built with it. State per backend, from the sources cloned
for reference (`psp_refs`) and web research:

| Backend | Player | Lua today | LuaJIT status |
|---|---|---|---|
| Vita (lpp-vita) | Lua Player Plus Vita, source available | **LuaJIT 2.1** (its README: "runs under LuaJIT 2.1 with slight additions from Lua 5.2.4", credits `vita-luajit` by hyln9) | already in use. Open point: whether JIT is on or interpreter only (not found in the sources read). |
| Vita (OneLua) | OneLua, binary | Lua 5.1-class | player binary only; would need a rebuild, source not available here. |
| 3DS | lpp-3ds, source available | PUC Lua 5.3.1 | LuaJIT supports ARM (v5T and later) so the CPU is not the blocker; no 3DS port found. Needs a custom lpp-3ds build; JIT would need executable memory, so interpreter only is the realistic mode. |
| PS3 | Lua player (Lua 5.2+ per `AGENTS.md`) | PUC Lua 5.2+ | PowerPC 64: upstream LuaJIT PPC is 32-bit/e500-oriented; a PPC64 fork exists but is marked deprecated; no PS3 port found. Unlikely. |
| PSP (OneLua) | OneLua binary, no source | PUC Lua 5.1 | not possible without replacing the player. |
| PSP (native engine, W17) | own build | PUC Lua 5.1, `float` numbers | LuaJIT supports MIPS32 little-endian; Allegrex has a single-precision FPU only while LuaJIT numbers are `double` (software float) — the project's own `float` Lua build measured about +30 % over `double`. Gated experiment; see the Balatro project's plan 2.9b. |

Conclusions:
1. **LuaJIT is not a lever for the wrapper on PSP/OneLua, 3DS or PS3 today.** On the platforms where a
   LuaJIT player could exist (3DS custom build, PSP native), it is an experiment, not a plan item with a
   promised gain.
2. **lpp-vita already has it**, so the Vita numbers will differ from the other backends; measure before
   assuming the optimisations above transfer (W20). Hot paths that were tuned for PUC Lua instruction
   counts (table access, closures) are still right under the LuaJIT interpreter, but its cost per
   instruction is different.
3. **Interpreter-only is the realistic mode on consoles** (no executable memory on retail systems except
   through exploits or kernel plugins). Then trace compilation does not apply, and what matters is the
   assembly interpreter's dispatch and its table/string fast paths, which tend to beat the PUC VM
   noticeably on ARM. This is a hypothesis; the experiment W21 must measure it.
4. Keep the code LuaJIT-clean (R2, W19): no 5.3 integer operators, no `goto` tricks, avoid constructs
   LuaJIT cannot compile if JIT is ever on (string.format with `%q`, `pairs` on huge tables in hot loops).

### Experiment W21 (gated)
Decision rule: adopt only if it gives at least 15 % on the synthetic frame wall time on the target, without
a regression in `tests/` and with a build that is reproducible from this repository's documentation.
1. Host check: build LuaJIT with `-DLUAJIT_DISABLE_JIT` for ARM (Vita/3DS) and run `frame_cost.lua`
   wall time against PUC Lua 5.1/5.3 under an ARM emulator or on the device. Host x86 numbers are not
   evidence for the consoles.
2. For lpp-vita: add a timing line to the bench (wall time per synthetic frame) and run on a Vita or
   Vita3K if available.
3. For PSP-native: follow the Balatro project's plan 2.9b (micro-benchmark `float` PUC vs LuaJIT
   soft-float in PPSSPP; stop if below 15 %).
4. Record the result in `PERFORMANCE_FINDINGS.md` section 7 whether it passes or fails.

## 4. Risks
- Instruction counts on the mocks do not capture cache and memory effects on real hardware.
- The polygon cache trades memory for CPU; bounded size (W7) is required on 32 MB devices.
- W5/W6 change the order in which draws reach the native layer; any blend/scissor change must flush.
- W17 introduces a second runtime; the shared contract (`tests/`) must run against it too.
- Unlicensed or restricted reference material (commercial game sources, projects without a licence) is for
  study only and must not be copied into this repository.

## 5. Out of scope
Porting any specific game to C; a general shader compiler (W33 only maps known effects to approximations); audio mixing beyond the two OneLua voices (W46 stays unless hardware audio exists).

## 6. Licensing note
The decompilation of the OneLua player is used to understand behaviour. The player's licence has not been checked yet; it must be verified before distributing any binary derived from or replacing it (W17, W23 tooling). Reference projects without a licence, and commercial game sources, are for study only.
