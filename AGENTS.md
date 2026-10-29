# AGENTS.md: LOVE-WrapLua

Orientation for anyone, human or AI agent, changing this repository.

---

## What this project is

**LOVE-WrapLua** is a Lua compatibility layer that lets LÖVE 11.5 games run
unmodified on retro console targets:

| Target | SDK | Platform files |
|---|---|---|
| PSP | **OneLua** (PSP sub-mode) | `LOVE-WrapLua/OneLua/` + `OneLua/psp/` |
| PS3 | **PS3 Lua Player** (tiny3D) | `LOVE-WrapLua/PS3/` |
| PS Vita (native) | **OneLua** | `LOVE-WrapLua/OneLua/` + `OneLua/graphics/` |
| PS Vita (alternative) | **lpp-vita** | `LOVE-WrapLua/lpp-vita/` |
| Nintendo 3DS | **lpp-3ds** | `LOVE-WrapLua/3DS/` |

A game author drops their LÖVE project into `game/` and boots the wrapper; the
wrapper re-implements the LÖVE 11.5 API on each platform's native Lua SDK.

**Platform priority: PSP > PS3 > Vita > 3DS.** When work could go to more than
one target, or a fix cannot be finished everywhere at once, the earlier
platform wins. The 3DS is the newest backend and last on purpose. Both Vita
backends (OneLua and lpp-vita) share the Vita slot.

The wrapper never runs on a desktop PC (the tests do, against mocks). There is
no build step and no package manager: everything is plain `.lua`.

---

## Repository layout

Every `love.*` module is an **entry point that loads one file per area of the
API**. Opening `OneLua/graphics.lua` shows the load order; the code lives in
`OneLua/graphics/`. Backend modules share state through `lv1lua.gfx`
(transform stack, font cache, platform constants), never through file locals,
since each file is a separate `dofile` chunk.

```
script.lua            Boot: ordered core/* steps, then the main loop.
index.lua / app.lua   Entry points (lpp-vita and 3DS / PS3).
game/                 The game (main.lua, conf.lua, assets); libraries/anim8.lua (upstream), desAnim8.lua.
docs/adr/             Architecture decision records.
tests/                See "Running the tests".
LOVE-WrapLua/
  core/               Backend-agnostic, no native calls:
                      loader (lv1lua.load/loadOnce), fileio (file seam; lpp-3ds has no io.open),
                      util (rounding, 0-1 to 0-255, UTF-8, warnings, draw-object registry),
                      transform (software stack), transformapi (love.graphics transform + scissor),
                      textwrap, font (face cache over gfx.fontHooks), text (printf), image,
                      state (colour/line/blend/filter/stencil), primitives (over 4 prim hooks),
                      polyfill (even-odd fill), texinset, objects (Canvas/Shader/SpriteBatch/Text),
                      particles, mesh (stub), audio (over lv1lua.audio.hooks), capabilities,
                      input (key edges/repeat/joystick), timestep (fixed step, stats, clock),
                      runtime (platform detect, screen size, love namespace), config (conf.lua,
                      lv1luaconf, buttons), modules (loads backend + shared), require (into game/),
                      callbacks (key-to-gamepad bridge).
  math.lua -> math/{random,noise,transform,geometry,color}.lua   shared, pure Lua
  filesystem.lua, data.lua (+vendor/), window.lua (always fullscreen), joystick.lua,
  system.lua (guarded SDK probes), love-functions/thread.lua (coroutine threads + channels)
  vendor/             sha2.lua, LibDeflate.lua (see vendor/README.md)
  OneLua/             graphics.lua + graphics/ (Vita), graphics_psp.lua + psp/ (PSP),
                      imagedraw.lua (draw for both), audio (2 channels), keyboard (+OSK),
                      timer, whileloop (draw/update/controls + touch), event, touch/mouse (Vita)
  lpp-vita/, PS3/     graphics.lua + graphics/{state,image,draw,font,text,primitives,info},
                      audio, keyboard, timer, whileloop, event
  3DS/                same, plus graphics/scissor.lua, text (deferred CPU print), fileio.lua
```

---

## Boot sequence

1. The console loads `index.lua` (lpp-vita and lpp-3ds; it tells them apart by
   the `TOP_SCREEN` constant only lpp-3ds defines) or `app.lua` (PS3), which
   set `lv1lua.dataloc` and `lv1lua.mode` and dofile `script.lua`. OneLua boots
   `script.lua` directly and the mode defaults to `"OneLua"`.
2. `script.lua` dofiles `core/loader.lua`, then in order: `core/util`,
   `core/transform`, `core/textwrap`, `core/runtime`, `love-functions/thread`,
   `core/input`, `core/config`, `core/timestep`, `core/modules` (backend, then
   shared modules), `core/require`. It seeds the RNG, loads `game/main.lua`,
   calls `love.load()`, wires `core/callbacks`, and enters
   `while lv1lua.running do … end`.
3. Each iteration calls `lv1lua.draw()`, `lv1lua.update()` and
   `lv1lua.updatecontrols()`, defined in the platform's `whileloop.lua`.

---

## Key global state

| Variable | Type | Meaning |
|---|---|---|
| `lv1lua` | table | Runtime state. Never nil. |
| `lv1lua.mode` | string | `"OneLua"` / `"lpp-vita"` / `"PS3"` / `"3DS"` |
| `lv1lua.isPSP` | bool | `os.cfw`: true when OneLua runs on a PSP |
| `lv1lua.dataloc` | string | Prefix prepended to every asset path |
| `lv1lua.saveloc` | string | The save directory (follows the identity on Vita and 3DS) |
| `lv1lua.screenWidth/Height` | number | PSP 480×272, Vita 960×544, PS3 720×480, 3DS 400×240 |
| `lv1lua.current` | table | Active graphics state: font, color, bgcolor, canvas, blendMode |
| `lv1lua.current.colorRGBA` | `{r,g,b,a}` | Colour in LÖVE's 0-1 range |
| `lv1lua.current.color` | native | The SDK colour built from it |
| `lv1lua.gfx` | table | Backend graphics state and hooks (see below) |
| `lv1lua.joystickState` | table | `{axes={…}, buttons={}, hats={"c"}}`, filled every frame |
| `lv1lua.keyset` | `{string×6}` | Face/shoulder button names: circle, cross, triangle, square, L, R |
| `lv1luaconf` | table | Wrapper config: `keyconf`, `imgscale`, `resscale`, `updaterate`, `maxframeskip` |
| `lv1lua.dt` | number | The fixed slice the current `love.update` was called with |
| `lv1lua.frameDelta` | number | The real frame time (render rate, key repeat) |
| `love` | table | The whole LÖVE API namespace |

---

## Backend hooks

Shared modules do the LÖVE-level work and call a backend only through hook
tables it installs **before** the shared module loads:

| Hook table | Installed by | Used by |
|---|---|---|
| `gfx.nativeColor / clearScreen / filterValue` | `graphics/state.lua` | `core/state.lua` |
| `gfx.prims` (fillRect, rectOutline, line, fillCircle, mapPoint, mapScale) | `graphics/primitives.lua` | `core/primitives.lua` |
| `gfx.fontHooks` (load, loadMeasure, measure, applySize, sizeAdjust) | `graphics/font.lua` | `core/font.lua` |
| `gfx.imageHooks` (setFilter, release) | `graphics/image.lua` | `core/image.lua` |
| `gfx.blendHooks.apply` | `graphics/state.lua` (PSP, PS3) | `core/state.lua` |
| `gfx.applyScissor` | `3DS/graphics/scissor.lua` | `core/transformapi.lua` |
| `gfx.blitImage / prepareCopy / snap` | OneLua `state.lua` (Vita, PSP) | `OneLua/imagedraw.lua` |
| `lv1lua.audio.hooks` | each `audio.lua` | `core/audio.lua` |
| `lv1lua.fileio` | `3DS/fileio.lua` (others default to `io`) | filesystem, audio, require |

---

## Colour

LÖVE 11 uses **0-1 floats**; every SDK here wants 0-255 integers. Convert with
`lv1lua.util.to255` only at the native call. `lv1lua.current.colorRGBA` keeps
the 0-1 values `getColor` returns; `lv1lua.current.color` holds the SDK colour.

**Game code using 0-255 colours is wrong**: a game-side bug, not a wrapper bug.

---

## Drawable protocol

`love.graphics.draw` dispatches on the drawable:

1. `lv1lua.util.isDrawObject(drawable)` (SpriteBatch, Text, ParticleSystem,
   Mesh, Canvas) calls `drawable:_draw(x, y, r, sx, sy, ox, oy)`. Objects that
   replay draws wrap them in `lv1lua.core.withDrawTransform`, so the whole
   object is placed, turned and scaled by the call.
2. Otherwise `lv1lua.core.texture(drawable)` unwraps an Image (`core/image.lua`)
   to its native handle in `_tex`; anything else is taken as a raw handle a
   library passed in.

`newImage` must return `lv1lua.core.wrapImage(handle, w, h)`, never the bare
handle: lpp-vita and lpp-3ds return textures as integers, and a method call on
one raises. A new drawable type implements `_draw` and registers itself with
`lv1lua.util.registerDrawObject`.

---

## Transform stack

`core/transform.lua` holds a stack of levels, each an offset, a scale and an
angle. `translate`, `scale` and `rotate` change the **top** level and compose
in that level's local space: `translate` adds `scale × delta` to the offset,
`scale` multiplies, `rotate` adds. `translate(10,0)` then `translate(5,0)` must
equal `translate(15,0)`. Levels flatten **outermost first**: a level's offset
is scaled by every level outside it, so `scale(2) push() translate(-10)` maps x
to `2(x - 10)`.

The flattened form has no off-diagonal terms, so rotation turns what is drawn
but does not rotate later positions, and `shear` is a stub.

Every backend folds the same stack into images, shapes and text: a point maps
as `p×S + O` (`stack:mapPoint`), a size as `w×S` (`stack:mapScale`). Shapes
built from other shapes (circle outline, ellipse, arc) emit **LÖVE-space**
vertices and let `polygon` map them once; never pre-map a radius.

> **lpp-vita native arg-order gotcha.** `Graphics.drawLine`, `Graphics.fillRect`
> and `Graphics.fillEmptyRect` take **`(x1, x2, y1, y2, color)`**: both X
> coordinates first, then both Y, not `(x1, y1, x2, y2)`. Verified against
> `lpp-vita/source/luaGraphics.cpp`; the mock encodes it so a mistake fails in
> tests. lpp-3ds uses the same order.

---

## Platform APIs

Native SDK APIs and gotchas per backend (OneLua, lpp-vita, lpp-3ds, PS3) are in `docs/sdk-apis.md`. Read it before touching a backend or its mock. Key lpp-3ds traps: `TOP_SCREEN` is `0`, `Color.new` returns an integer, integer-only args raise on fractions, and shared code must open files through `lv1lua.fileio`.

---

## Running the tests

Tests run on desktop Lua 5.1, 5.3, 5.4 and LuaJIT; no console SDK is needed.

```bash
lua tests/run_all.lua          # everything, from the project root
lua tests/math_test.lua        # one suite
```

GitHub Actions (`.github/workflows/ci.yml`) runs the suite on lua 5.1 / 5.3 /
5.4 / luajit. Run it locally on at least lua5.1, lua5.4 and luajit before every
commit.

### Test architecture

- `tests/runner.lua`: a fresh runner per `dofile`. `describe`, `it`,
  `eq / near / ok / nok / istype / inrange`, `summary()` returns the failure count.
- `tests/mock_common.lua`: backend-agnostic mock: `lv1lua`, `lv1luaconf`, a
  fresh `love`, the VFS `files`, input stubs, and the native-call recorder
  `__rec` (`reset`, `log`, `last`, `all`, `count`). Re-dofiling it resets all
  state, so one process can exercise every backend.
- `tests/mock_onelua.lua`, `mock_lppvita.lua`, `mock_ps3.lua`, `mock_3ds.lua`:
  per-backend native APIs, **grounded in the SDK sources**: native argument
  orders, `luaL_checkinteger` arguments (`__checkInteger`), which calls exist
  at all, and what they do to state (lpp-vita `Sound.play` resets the volume).
  A mock that is kinder than the SDK hides device crashes; extend it from the
  SDK source, not from what the wrapper happens to call.
- `tests/setup.lua`: loads `mock_common` then the backend mock for `__MODE`
  (`"OneLua"`, `"PSP"`, `"lpp-vita"`, `"PS3"`, `"3DS"`; default `"OneLua"`).
- `tests/mock_platform.lua`: shim, `setup.lua` pinned to OneLua.
- Suites are named `<area>_test.lua`. Each one dofiles the runner, then a mock,
  then the module under test, then its cases, and returns `T.summary()`.
  Register a new suite in `tests/run_all.lua`.
- Multi-backend suites loop over the modes (`primitives_test`,
  `transform_api_test`, `objects_test`, `audio_test`, `image_test`,
  `scissor_test`, `event_test`, `system_test`, `font_test`, `text_test`, …).
- `tests/globals_test.lua` fails on any global outside the six the wrapper owns.

---

## Known limitations

| Feature | Status |
|---|---|
| Canvas | Stub: `renderTo(fn)` draws to the screen, drawing the Canvas does nothing (`canvas=false`) |
| Shader / Mesh | Stubs: objects exist, nothing renders |
| Rotation in the stack | Turns what is drawn, not later positions; `shear` is a stub |
| OneLua draws | Scaled / mirrored copy per sheet; a rotated quad turns the whole copy; quads tint alpha only |
| Scissor | Software reject on lpp-vita, GPU on the 3DS, tracked elsewhere |
| PS3 | Draws through tiny3D; unverifiable in RPCS3; no timer (frame clock), one stream voice |
| 3DS text | Printed after the GPU pass, always on top; lines starting off screen are skipped |
| love.audio | Positions and pitch timed in software; `seek` moves the reported position only |
| Blend modes | Real on the PSP (`add` / `subtract`, whole images) and PS3 (all eight); tracked on both Vita backends and the 3DS |
| love.thread | Synchronous coroutines; `Channel:demand` never blocks |

Per-function detail lives in `Implemented.md`.

---

## Coding conventions

- **No comments by default.** Comment only a non-obvious WHY (a hidden
  constraint, an SDK quirk, a workaround). State the current reason: no history
  narration ("used to", "the old copies") and no references to task or review
  IDs, which outlive the documents they point into.
- **No global leaks.** Every temporary is `local`. The wrapper owns exactly six
  names in `_G`: `love`, `lv1lua`, `lv1luaconf`, `require` (redirected into
  `game/`), `__mathRound` (legacy alias) and `loadstring` (PS3 runs Lua 5.2+).
  `tests/globals_test.lua` fails on a seventh; if one is genuinely needed, add
  it there with the reason.
- **Colour 0-1 everywhere** in the public API; convert only at the native call.
- **Shared first.** Logic that needs no native call belongs in `core/` (or a
  shared module) behind a hook table, not copied into each backend.
- **Shared modules** (`core/`, `math/`, `data.lua`, `window.lua`,
  `joystick.lua`, `filesystem.lua`, `system.lua`, `thread.lua`) never touch a
  platform global except through a guarded probe or `lv1lua.fileio`.
- **Platform modules** may use their SDK's globals freely and never import from
  another platform's directory. The OneLua Vita and PSP builds share
  `OneLua/` because they share the SDK.
- **Button maps instead of if-elseif chains** (see the whileloops).
- **LuaLS types.** `.luarc.json` sets `runtime.version` to `Lua 5.5` and uses `${3rd}/love2d/library` as the reference: a wrapped function must keep the signature and return values of the LÖVE 11 function it replaces. Types for API that exists only in this wrapper (`lv1lua` and other extras) go in `types/` as `---@meta` files with `---@class`, `---@param`, `---@return`, updated with every public change; create `.luarc.json` and `types/` if missing. Check with `lua-language-server --check . --configpath .luarc.json --checklevel Warning` (the binary ships inside the `sumneko.lua` VS Code extension, under `server/bin/`).

---

## Rules for AI agents

Read before committing anything.

- **Commit authorship is fixed.** Every commit and push is authored solely by
  `Legendary Redfox <legendaryredfox.dev@gmail.com>`:
  `git commit --author="Legendary Redfox <legendaryredfox.dev@gmail.com>"`.
- **No AI trailer.** Never add `Co-Authored-By: Claude`, "Generated with", or
  any AI attribution line to commit messages, PR bodies, or code.
- **No em-dashes.** Do not use the em-dash character in prose, docs, code
  comments, or commit messages. Use a comma, parentheses, a colon, or reword.
- **Never commit on `master` directly.** Branch first (`fix/...`, `feat/...`).
- **Test-first for behaviour changes.** Add a test that fails before the fix and
  passes after. Run the full suite before every commit; it must be green on
  lua 5.1 and 5.4 at minimum (and LuaJIT).
- **LuaJIT / Lua 5.1 compatible.** No 5.3+ integer operators (`//`, `&`, `|`,
  `<<`, `>>`), no `<const>` / `<close>`, no `math.type`. Use
  `table.unpack or unpack` and `math.atan2 or math.atan`.
- **Ground native calls in the SDK source.** Before relying on a native call's
  argument order, integer-ness or side effects, read it in the SDK's C binding
  and make the mock match.
- **Keep backends independent** (see Coding conventions).
- **Update `Implemented.md`** whenever API coverage or a documented limitation
  changes, and add a `Changelog.md` entry.
- One logical change per commit, Conventional Commits subject
  (`fix(scope): …`, `feat(scope): …`, `test: …`).

---

## Common tasks

### Adding a love.graphics function
1. If it needs no native call, put it in `core/` and have every backend load
   it; if it does, add a hook to the right hook table and implement the hook
   in each backend: `OneLua/graphics/`, `OneLua/psp/`, `lpp-vita/graphics/`,
   `PS3/graphics/`, `3DS/graphics/`.
2. A stub returns the right type, so call sites do not crash.
3. Cover it in a multi-backend suite and update `Implemented.md`.

### Adding a submodule to a backend
1. Create `LOVE-WrapLua/<backend>/graphics/<area>.lua`.
2. Add an `lv1lua.load` line to that backend's `graphics.lua` in dependency
   order (`state` first, hooks before the shared module that reads them, `font`
   before `text`).
3. Share state through `lv1lua.gfx`, never file locals.

### Adding a shared module
1. Create `LOVE-WrapLua/<module>.lua` (an entry point if it needs more than one
   file, the parts in `LOVE-WrapLua/<module>/`).
2. Initialise its namespace in `core/runtime.lua` (`love.<module> = {}`).
3. Add an `lv1lua.load` line in `core/modules.lua`.
4. Add `tests/<module>_test.lua` and register it in `tests/run_all.lua`.

### Changing the key layout
Edit `lv1lua.keyset` in `core/config.lua`. The six entries map to circle,
cross, triangle, square, L, R; `lv1lua.keyset[1]` is always the confirm button.
An unknown `keyconf` falls back to `"XB"` with a warning.

### Adding a platform (do this last)
A new backend comes after every improvement to the existing ones. The 3DS was
the last planned target; none is planned after it. Switch / Horizon is out of
scope: do not start one, and do not list it as a target. Ground the new
backend's mock in the SDK's own source **before** writing the backend.

1. Create `LOVE-WrapLua/<platform>/` with `graphics.lua` and its `graphics/`
   submodules (state, image, draw, font, text, primitives, info), plus
   `audio.lua`, `keyboard.lua`, `timer.lua`, `whileloop.lua`, `event.lua`.
2. Extend the mode detection and screen size in `core/runtime.lua`, and add a
   record to `core/capabilities.lua`.
3. Add `tests/mock_<platform>.lua`, register it in `tests/setup.lua`, and add
   the backend to the multi-backend suites.

---

## Files not to touch

| File | Reason |
|---|---|
| `game/libraries/anim8.lua` | Unmodified upstream library |
| `LOVE-WrapLua/Vera.ttf` | Default font binary |
| `LOVE-WrapLua/vendor/*.lua` | Vendored upstream code; see `vendor/README.md` for the one local patch |
