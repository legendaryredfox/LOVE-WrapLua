# Native PSP backend: audit of what exists (2026-11-17)

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
stat mkdir remove deflate inflate b64encode b64decode`.

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
| Audio | silent stub, 0 voices | OneLua 2 channels, lpp-vita, 3DS, PS3 stream |
| Canvas | real render-to-texture, 2 targets in VRAM, 512 max | stub on every backend |
| Shader / Mesh | stubs | stubs |
| Rotation and scale | on the GPU | OneLua copies the image per scale or turn |
| Text | TTF through stb_truetype, atlas pages | SDK font calls |
| `love.math` | `random`, `setRandomSeed` only | noise, triangulate, bezier, Transform, RandomGenerator, colour helpers |
| `love.data` | compress, decompress | hash, encode, pack, compress |
| SpriteBatch, Transform | absent | present |
| ParticleSystem, Text | present in `love_psp.lua`, no curves | basic emitter with curves; Text with replay |
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

## 5. Risks and open items

- `balatro_psp` is not under version control. Its `git init` and `.gitignore` are open items in its own
  HANDOFF (section 5, item 11).
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

## 6. Suggested order

1. Put the engine and its Lua backend under version control in this repository as `native/` and
   `LOVE-WrapLua/native/`, with the docker build pinned and `tests/backend/` registered in `tests/run_all.lua`.
2. Add a `"PSP-native"` mode to `core/runtime.lua` and a `native` row to `core/capabilities.lua`, so the shared
   test suites can run it against the existing mock style (`tests/mock_native.lua`).
3. Replace the duplicated `love.math`, `love.data`, `love.thread`, `love.filesystem` and `love.joystick` parts of
   `love_psp.lua` with the shared modules (these need no native call).
4. Decide the transform-stack question in section 4, then move graphics onto the hook tables one area at a time,
   measuring `frame_cost` and the Balatro bench after each.
5. Audio (`sceAudio`), then ParticleSystem curves and SpriteBatch on the native path, then the remaining
   `love.graphics` stubs.
