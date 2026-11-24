# Native PSP backend: audit of what exists (2026-11-17)

Goal (user, 2026-11-17): write games for the PSP with LÖVE, and a game like Balatro must run smoothly, so
performance is part of the objective. The engine may be C; the `love.*` layer, the game and every development
step stay in Lua.

Scope: the native PSP engine that lives in `~/development/games/balatro_psp` (not a git repository), judged as a
candidate first-class PSP backend for LOVE-WrapLua. Nothing here was changed in either repository.

## 1. What exists

| Part | Where | Size | Notes |
|---|---|---|---|
| C engine | `native/src/engine.c`, `main.c`, `lbit.c` | 798 + 73 + 41 lines | sceGu rendering, textures, canvases, TTF, pad, fs, zlib, base64, memory probes |
| Lua 5.1.5 | `native/third_party/lua-5.1.5` | upstream | built into the EBOOT; `-DPSP_LUA_FLOAT` makes numbers single precision (default) |
| LÖVE backend | `backend/love_psp.lua`, `boot.lua`, `psp_ffi.lua` | 938 + 138 + 292 lines | one self-contained `love.*` implementation over the C module `native` |
| Tests | `tests/backend/` | 68 cases | run on desktop Lua 5.1 with `native` mocked |
| Build | `tools/build_native.sh` | docker `pspdev/pspdev` | `make` with `BUILD_PRX=1`, `PSP_LARGE_MEMORY=1`; the image is present locally |
| Docs | `docs/HANDOFF.md`, `BACKEND_PSP_NATIVO.md`, `PLAN_PERFORMANCE.md` | | Portuguese; HANDOFF is the entry point |

`native` exports 46 functions: `image_load tex_filter draw fill_poly fill_rect line set_color get_color push pop
prep_draw origin reset_stack translate scale rotate begin_frame clear end_frame scissor blend font_load font_width
font_has font_draw canvas_new canvas_set canvas_pixel palette pad time sleep mem tex_mem suppress cpu exit listdir
stat mkdir remove deflate inflate b64encode b64decode`, plus `draw_mesh` and `tex_pixel` added since.

## 2. Measured today

Balatro `SELECTING_HAND`, PPSSPP through RetroArch, same seed and scene as the wrapper numbers:

| Path | update | draw | fps |
|---|---|---|---|
| native engine (`tools/bench.sh 16000`, 2026-11-17) | 31.4 ms | 29.7 ms | 16.4 |
| LOVE-WrapLua on OneLua (PSP) | 105 ms | 372 ms | 1.1 |

About 15x. The native update is 3.4x cheaper for the same game Lua, which is the Lua VM running with a trimmed
set of Lua-to-C crossings and float numbers, plus the game's own optimisations in `psp/opt.lua`. Gate 1 of the
native plan is 20 fps; it is at 16.4.

Tests: `tests/backend/run.sh` gives 68 passed, 0 failed.

## 3. Gaps against LOVE-WrapLua

`love_psp.lua` is a parallel implementation of `love.*`, written without `core/`, `math/` or `data.lua`. It
documents itself as `tier 2`.

| Area | Native backend | LOVE-WrapLua |
|---|---|---|
| Audio | **done 2026-11-17, MP3 only since 2026-11-21**: C mixer thread, 24 voices, `.mp3` on the Media Engine, static or streamed, pitch, volume, loop, seek, clone | OneLua 2 channels, lpp-vita, 3DS, PS3 stream |
| Canvas | real render-to-texture, 2 targets in VRAM, 512 max | stub on every backend |
| Shader / Mesh | Shader stub; **Mesh done 2026-11-22** (`native.draw_mesh`, default vertex format, single-tile textures) | stubs |
| Rotation and scale | on the GPU | OneLua copies the image per scale or turn |
| Text | TTF through stb_truetype, atlas pages; **ImageFont done 2026-11-22** (`native.tex_pixel` finds the glyph columns, Lua draws one quad per glyph) | SDK font calls |
| `love.math` | shared module over the C generator (`PSPNative/shared.lua`) | noise, triangulate, bezier, Transform, RandomGenerator, colour helpers |
| `love.data` | compress, decompress | hash, encode, pack, compress |
| SpriteBatch, Transform | **done 2026-11-17** (shared Lua over the C draw; `love.math` Transform from the shared module) | present |
| ParticleSystem, Text | **ParticleSystem done 2026-11-17** (shared, with curves; it was an inert stub); Text present | basic emitter with curves; Text with replay |
| Stencil | partial | stub |
| Blend modes | alpha, add, multiply (subtract and screen fall back to alpha) | add and subtract on PSP |
| Threads | cooperative coroutines | cooperative coroutines |
| Joystick, keyboard, window, system | basic | full surface, capability table |
| Scissor | GPU | GPU |
| Transform stack | in C (`native.push/pop/translate/scale/rotate`) | software stack in `core/transform.lua` with shear |

## 4. Integration shape

The wrapper already lets a backend plug in through hook tables (`gfx.prims`, `gfx.fontHooks`, `gfx.imageHooks`,
`gfx.blendHooks`, `lv1lua.audio.hooks`, `lv1lua.fileio`). A native backend is a sixth backend of that kind,
with two decisions that change the design:

1. **Who owns the transform stack.** The C engine applies the matrix on the GPU, so the software stack in
   `core/transform.lua` would be bypassed for images and used only for shapes the engine cannot take.
   `core/primitives.lua` maps every vertex through the Lua stack (`mapPoint`), which the native path does not need.
   Either the backend keeps the C stack and installs identity `mapPoint` / `mapScale` / `mapShear` hooks, or the
   Lua stack stays authoritative and the engine receives matrices. The first is cheaper per call; the second
   keeps shear and `inverseTransformPoint` exact.
2. **Lua crossings are the cost.** The engine got to 16 fps by moving work into C (`set_color`, batching,
   `draw_pixellated_rect`) and by trimming Lua per call. Routing every call through the shared `core/` layers
   adds Lua instructions per draw, the thing the OneLua wrapper is slow at. The shared layer would need a
   native fast path for `draw`, `setColor`, `push`, `pop`, `translate`, `rectangle` and `print`, like the 213 and
   168 call mix in `tests/bench/frame_cost.lua`.

### Decision: the matrix stack stays in C (2026-11-17)

Measured with `tests/games/stackbench` on the packaged EBOOT in PPSSPP (virtual clock, mean of 40 frames after
warm-up), one synthetic frame of the `frame_cost.lua` mix (213 push/translate/scale/pop, 124 quad draws,
168 setColor, 54 polygon fills, 45 prints):

| Stack | ms per frame |
|---|---|
| in C (`love.graphics.push` and friends call the engine, which applies the matrix) | 5.80 |
| in Lua (software levels as in `core/transform.lua`, draws placed with the flattened result) | 10.00 |

The Lua stack costs 4.2 ms more, about 13% of a 33 ms budget, and it cannot compose a rotation into the positions
that follow it (the flattened form has no off-diagonal terms), so `rotate(a) translate(10, 0)` lands in the wrong
place. The C matrix is a full 2x3 affine, exact for rotation and, with the additions below, for shear.

C gained `shear`, `get_matrix`, `set_matrix` and `mul_matrix`; Lua wraps them as `love.graphics.shear`,
`transformPoint`, `inverseTransformPoint`, `applyTransform` and `replaceTransform`. The shared `core/transform.lua`
is therefore not used by this backend. `tests/games/matrix` checks the C answers on the console build.

### Profile of the native path, `SELECTING_HAND` (2026-11-17)

Sampling profile (hook every 5000 VM instructions, 1840 samples, the Balatro harness with `PROFILE=1`), built from
this repository's engine and backend. The harness now builds through `lua tools/lovepsp.lua build`, and the
unprofiled baseline from that build is the same 16.4 fps (update 31.4 ms, draw 29.8 ms).

| Share of samples | Where |
|---|---|
| 30% inclusive, 16% self | `Moveable:move` (the harness's reduced version in `psp/opt.lua`) |
| 20% inclusive, 8% self | `UIElement:draw_self` (`ui.lua`) |
| 16% inclusive | `CardArea:draw` and `Card:draw` |
| 4% inclusive | `love_psp.lua` `love.graphics.draw` (the backend itself) |
| about 2% each | `Sprite:draw_self`, `DynaText`, `Node:update`, `love_psp.lua` text path |

- The backend layer is about 5% of the frame. What is left is Balatro's own Lua on the Lua VM, spread over many
  functions; no single C or backend change moves it by more than a few percent.
- Compiler flags are not a lever: `-O3 -fno-strict-aliasing` gives 31.7 + 29.8 ms (16.3 fps) against 31.4 + 29.8
  with `-O2`.
- Levers that remain, by size of the expected gain (estimates from `PLAN_PERFORMANCE.md`, not yet measured here):
  caching static UI in a canvas (`-8` to `-14 ms`, canvases are real in this engine), moving `Moveable:move` and
  the other per-node updates to C behind the same field API (`~-8 ms` for `move` alone), skipping invisible nodes,
  and `Game:update` work done at 1 Hz. Reaching 30 fps needs several of them; the first two are the large ones.
  **Update 2026-11-23:** the `Moveable:move` fast path is in C (`native/src/moveable.c`): update 32.2 to 25.9 ms, 18.6 to 21.1 fps with the
  UI cache on. Reading fields through the public Lua API is no faster than the VM; only direct table access (`luaH_getstr`) pays, about
  9x on the idle check. `get_major`, `move_with_major` and the per-field `move_*` functions followed the same day:
  update 25.9 to 17.7 ms and 25.6 fps in all, `update:move` 15.7 to 8.1 ms per frame. Objects with a `juice` stay in Lua.
  The UI cache signature walk (`native/src/uiwalk.c`) took draw from 21.5 to 19.4 ms (27.1 fps), and the round-robin update gate
  (`native/src/reduce.c`) update from 17.6 to 16.1 ms (28.2 fps). The two `MOVEABLES` loops of `Game:update` in C (`mv_loop`, `mv_update_loop`)
  took update to 14.6 ms (29.4 fps).
  `prep_draw` and `Node:translate_container` in C (`prep_method`, `tc_method`) took draw from 19.4 to 17.1 ms: 31.8 fps in PPSSPP,
  past the 30 fps target of this phase (emulator figure, not hardware).

### Cost of audio in Balatro (2026-11-17)

With the audio mixer on, Balatro's `SELECTING_HAND` runs at 11.9 fps (update 43.7 ms, draw 40.5 ms); with every
source silent (`noaudio.flag` next to the EBOOT) it is the 16.4 fps of before (31.3 + 29.7 ms). Mixing and software
Ogg decoding on the one 333 MHz core cost about 12.7 ms per frame, three times the whole backend layer. A game that
plays music on the PSP cannot afford that. Levers, cheapest first: stream music at a lower rate or in mono, mix at
22.05 kHz, skip interpolation when pitch is 1 and the rate is 44.1 kHz, and decode on the Media Engine (the
`sceMp3` library, with the assets converted to MP3 by the packaging tool using ffmpeg) so the main core only mixes.
The Balatro harness builds with audio off by default so its numbers stay comparable; `AUDIO=1` turns it on.

Measured, no gain: a mixer fast path (tight per-chunk loops, no interpolation at pitch 1 and 44.1 kHz, bit-exact
against the old loop on desktop) gave 12.0 fps (43.0 + 40.0 ms) against 11.9 (43.7 + 40.5), within noise, and was
dropped. The mixing arithmetic is not the cost; software Ogg decoding (Tremor) is the likely one (not yet profiled alone). The levers that remain are the
ones that remove decode work from the main core: MP3 on the Media Engine, or music pre-decoded at a lower rate.
Decision (2026-11-17): MP3 on the Media Engine as the only format, see `docs/adr/002-psp-native-audio-format.md`.
Implemented 2026-11-21 on `sceAudiocodec` (`sceMp3` has 2 handles, Balatro streams 5 or more tracks), plus a tighter mixer
loop: Balatro SELECTING_HAND 16.2 fps with audio against 16.3 silent and 11.8 with Ogg; the gate of the ADR is met. Ogg, WAV
and Tremor were then removed (ADR 002).

### UI layer cache in a canvas (2026-11-17, in progress, not merged anywhere)

Code: section 7 of `~/development/games/balatro_psp/psp/opt.lua` (that repository is a local git repository since
2026-11-22, with no remote). Switch on with `OPT_ON=shadowoff,uicache[,walk2]` in `tools/build_native.sh`; add
`uidiag2` for per-box timing and the reason a box is not cached (`UICACHE box ...` lines in `psp_log.txt`).
Section 6 (`uidiag`) is the measurement that justified it, section 8 (`shadowoff`) forces Balatro's shadows option off.

Measured first (SELECTING_HAND, 400 updates): top-level UIBoxes cost 19.9 ms per frame of draw, of which 5.1 ms are
`UIT.O` objects (DynaText, sprites) and about 14.8 ms are the static elements. Boxes are 99% unchanged between
frames, so the estimate of `-8` to `-14 ms` is plausible.

How it works: a top-level UIBox whose per-element signature (position, size, colour, text, hover and press state,
parallax) is unchanged for two frames is drawn once into a 512x256 atlas canvas, skipping its objects, and from then
on as one quad. Objects, `add_to_drawhash` calls and elements with translucent colour that have no opaque ancestor
are replayed live around the quad. Decisions that came from the engine and the game:

- The cache is built in the box's local space and drawn under the live matrix. Balatro's room has a tiny rotation
  that changes every frame (`translate_container`), so a cache keyed on the matrix never hit.
- Shadows must be off. The engine writes alpha 255 for anything drawn into a canvas (stencil replace, see
  `engine.c`), so a translucent pixel over nothing turns opaque. Translucent elements over an opaque ancestor are
  exact; uncovered ones are drawn live under the quad (siblings do not overlap, so the order holds).
- Signature positions are quantised to 1/4 px; without that, springs that converge forever never become stable.
- The cached region is clipped to the screen plus 24 px, using the inverse of the current matrix. The VRAM pool
  holds one 512x256 canvas, and the engine's own `G.CANVAS` request is a null canvas.

Results (PPSSPP, deterministic): `shadowoff` alone 17.1 fps (update 31.4, draw 27.1). `shadowoff,uicache` 16.4 to
17.0 fps (draw 26.5 to 28.3): about 8 boxes per frame are cached and hit, and the output matches the uncached
screenshot except slightly softer text edges. No net gain yet, because the box that matters is not cached.

Strips (2026-11-22, PPSSPP, same bench): a region taller than 256 rows is cut into strips of at most 256 rows, one
atlas rect, scissor and quad each. A canvas takes `512 * pow2(height) * 4` bytes of the 0xF0000-byte VRAM pool, so
one 512x448 atlas does not fit (it rounds to 512x512). The cache uses a 512x256 atlas plus a 512x128 overflow atlas,
and the 797-node box (123x322, 2 strips) is now cached with no atlas failures. `shadowoff,uicache` runs at 17.7 to
18.0 fps (draw 23.3 to 23.9 ms) against 17.1 for `shadowoff` alone (draw 27.1 ms). Two traps found on the way:
`UIBox:draw` returns early when the box already drew this frame, so the second strip pass must bypass that guard
and must not start a nested cache build of a child box; and the objects inside a child UIBox (a controller button pip)
were neither collected nor drawn into the atlas, so `info` now walks the child's `UIRoot` too. Pips only appear
after the controller flag turns on, so compare screenshots at 70000 frames, not 20000.

Signature walk (2026-11-22): the per-node walk costs about 8.7 us, close to what drawing a node costs, so a hit saved
little. `OPT_ON=walk2` skips the walk on every other frame for a box that has been stable for 8 frames and blits the
cache: `shadowoff,uicache,walk2` 18.6 fps (draw 21.6 ms) against 17.8 for `shadowoff,uicache` (draw 23.9 ms) at 70000
frames. A change shows up one frame late. The remaining changing boxes are real motion (position of the hand and
joker areas) or a wobbling rotation (`VT.r` about -0.1 on the 25-node box), so quantising the signature field gains
nothing. A full-blind autoplay (`AUTOPLAY=hand`) reaches the shop with the same layout cached and uncached.

Open, in order:
1. (done, see above) The 797-node box, cached in strips.
2. (done) The 25-node box changes because it rotates, not because of scale: nothing to quantise.
3. (done) The walk costs as much as a draw; `walk2` skips it on alternate frames.
4. Shop checked; blind select and overlays still to diff, and a test
   game in `tests/games/` that exercises canvas plus quad blits so the engine side stays covered (done 2026-11-24:
   `tests/games/canvas`, packaged but its screenshot not yet compared in an emulator).
5. If it pays, move the code from `opt.lua` into a reusable place and decide whether the PSP default is shadows off
   (also worth about `-2.7 ms` by itself).

## 5. Risks and open items

- `balatro_psp` is a local git repository (2026-11-22) with no remote; `build/` and `native/` are ignored because
  they hold Steam assets and stale engine copies.
- Lua 5.1.5 sources sit in `native/third_party` and would be fetched or vendored, not committed as-is. The docker
  build needs a pinned image tag; `pspdev/pspdev:latest` is what runs today.
- The repository rule "no build step, plain `.lua`" (AGENTS.md) would have to change: the native backend needs a
  C toolchain to produce the EBOOT, while the Lua side can stay testable on desktop with `native` mocked, as
  `tests/backend/` already does.
- Heap: the PSP gives Lua about 40 to 45 MB, shared with textures and C allocations. "not enough memory" with no
  traceback is the symptom.
- Verified only in PPSSPP. A run on real hardware has not happened.
- `PSP_LARGE_MEMORY` and `BUILD_PRX` are set; EBOOT size is about 690 KB.
- Balatro and Gravity Circuit are the only validators. Neither is committed anywhere; the bench harness
  depends on a local Steam copy.

## 6. Performance target

"Smoothly" is taken as a steady 30 fps in Balatro's heaviest scene, `SELECTING_HAND` (33 ms for update and
draw together). Today: 16.4 fps (31.4 + 29.7 ms). The native plan's Gate 1 is 20 fps. Every step below is
measured with `tools/bench.sh` in the Balatro harness and with the synthetic `frame_cost` bench, and a change
that costs frame time needs a reason. Levers already identified in `PLAN_PERFORMANCE.md`: fewer Lua-to-C
crossings, batching, a game-side update diet (`Game:update` at 1 Hz, invisible nodes skipped), and a C hybrid for
`Node` / `Moveable` behind the same Lua field API.

## 7. Suggested order

1. Put the engine and its Lua backend under version control in this repository as `native/` and
   `LOVE-WrapLua/PSPNative/`, with the build and packaging as Lua (`tools/lovepsp.lua`) and the contract suite
   registered in `tests/run_all.lua`. **Done 2026-11-17** (see the Changelog); a clean build takes 15 s and a
   packaged sample game renders in PPSSPP.
2. (matrix ownership decided: C, see section 4) Add a `"PSP-native"` mode to `core/runtime.lua` and a `native` row to `core/capabilities.lua`, so the shared
   test suites can run it against the existing mock style (`tests/mock_native.lua`).
3. Replace the duplicated `love.math`, `love.data`, `love.thread`, `love.filesystem` and `love.joystick` parts of
   `love_psp.lua` with the shared modules (these need no native call).
4. Decide the transform-stack question in section 4, then move graphics onto the hook tables one area at a time,
   measuring `frame_cost` and the Balatro bench after each.
5. Audio (`sceAudio`), then ParticleSystem curves and SpriteBatch on the native path, then the remaining
   `love.graphics` stubs.
