# AGENTS.md — LOVE-WrapLua

This document is a complete orientation for AI agents working on this repository.  Read it fully before making any change.

---

## What this project is

**LOVE-WrapLua** is a Lua compatibility layer that lets LÖVE 11.5 games run unmodified on three retro console targets:

| Target | SDK | Platform files |
|---|---|---|
| PS Vita (native) | **OneLua** | `LOVE-WrapLua/OneLua/` |
| PSP | **OneLua** (PSP sub-mode) | `LOVE-WrapLua/OneLua/graphics_psp.lua` |
| PS3 | **PS3 Lua Player** | `LOVE-WrapLua/PS3/` |
| PS Vita (alternative) | **lpp-vita** | `LOVE-WrapLua/lpp-vita/` |

A game author drops their LÖVE project into `game/` and boots the wrapper; the wrapper re-implements the LÖVE 11.5 API surface using each platform's native Lua SDK.

The wrapper is not executed on a desktop PC.  There is no build step and no package manager.  All files are plain `.lua` scripts.

---

## Repository layout

Every `love.*` module is an **entry point that loads one file per area of the
API**.  Opening `OneLua/graphics.lua` shows you the load order; the code lives
in `OneLua/graphics/`.  Backend modules share state through `lv1lua.gfx`
(transform stack, font cache, platform constants) — never through file-locals,
since each file is a separate `dofile` chunk.

```
LOVE-WrapLua/
├── script.lua                  ← Boot: ordered core/* steps, then the main loop.
├── index.lua / app.lua         ← Platform entry points (loaded by the console OS).
├── game/                       ← User game code lives here (main.lua, conf.lua, assets …).
│   └── libraries/
│       ├── anim8.lua           ← LÖVE anim8 animation library (standard, unmodified).
│       └── desAnim8.lua        ← Console port of anim8 (uses imgData field of love.Image).
├── LOVE-WrapLua/
│   ├── core/                   ← Backend-agnostic, no native calls.
│   │   ├── loader.lua          ← lv1lua.load / loadOnce — dofile with the data prefix.
│   │   ├── util.lua            ← Rounding, 0-1↔0-255 colour, UTF-8 glyph iteration.
│   │   ├── transform.lua       ← Software transform stack (push/pop/flatten).
│   │   ├── textwrap.lua        ← Greedy word wrap, measured by the font itself.
│   │   ├── runtime.lua         ← Platform detection, screen size, love namespace.
│   │   ├── config.lua          ← game/conf.lua, lv1luaconf, button layout.
│   │   ├── modules.lua         ← Loads the backend + shared modules.
│   │   ├── require.lua         ← Redirects the game's require into game/.
│   │   └── callbacks.lua       ← Gamepad↔key bridging + callback stubs.
│   ├── math.lua                ← love.math entry → math/{random,noise,transform,
│   │                             geometry,color}.lua (shared, pure Lua).
│   ├── filesystem.lua          ← love.filesystem (shared, uses io.* or platform VFS).
│   ├── data.lua                ← love.data  (shared, pure Lua — base64/hex/ByteData).
│   ├── window.lua              ← love.window (shared, stubs for always-fullscreen console).
│   ├── joystick.lua            ← love.joystick (shared, wraps lv1lua.joystickState).
│   ├── system.lua              ← love.system (shared, tiny — getOS/getLanguage/getUsername).
│   ├── love-functions/
│   │   └── thread.lua          ← love.thread (coroutine-based pseudo-threads + channels).
│   ├── OneLua/
│   │   ├── graphics.lua        ← Entry: love.graphics for Vita (OneLua SDK).
│   │   ├── graphics/           ← state, transform, image, draw, font, text,
│   │   │                         primitives, canvas, spritebatch, textobject,
│   │   │                         mesh, particles, info.
│   │   ├── graphics_psp.lua    ← Entry: love.graphics for PSP.
│   │   ├── psp/                ← state, transform, image, font, text,
│   │   │                         primitives, objects, info.
│   │   ├── audio.lua           ← love.audio (OneLua sound.* API, 2 channels).
│   │   ├── keyboard.lua        ← love.keyboard (OneLua buttons.* API).
│   │   ├── timer.lua           ← love.timer (OneLua timer.* API).
│   │   ├── whileloop.lua       ← draw/update/updatecontrols per-frame hooks.
│   │   ├── callbacks.lua       ← Platform callback setup.
│   │   ├── event.lua           ← love.event (quit, pump stubs).
│   │   ├── touch.lua           ← love.touch (front touchscreen, Vita only).
│   │   ├── mouse.lua           ← love.mouse (mapped to touch).
│   │   ├── font.lua            ← Font helper utilities.
│   │   └── shader.lua          ← Pixel-cache shader stub.
│   ├── lpp-vita/
│   │   ├── graphics.lua        ← Entry: love.graphics (lpp-vita Graphics.* API).
│   │   ├── graphics/           ← state, transform, image, draw, font, text,
│   │   │                         primitives, objects, info.
│   │   ├── audio.lua           ← love.audio (lpp-vita Sound.* API).
│   │   ├── keyboard.lua        ← love.keyboard (lpp-vita Controls.* API).
│   │   ├── timer.lua           ← love.timer (lpp-vita Timer.* API).
│   │   ├── whileloop.lua       ← Per-frame hooks.
│   │   └── event.lua           ← love.event.
│   └── PS3/
│       ├── graphics.lua        ← Entry: love.graphics (PS3 Lua Player, many stubs).
│       ├── graphics/           ← state, transform, image, font, text,
│       │                         primitives, objects, info.
│       ├── audio.lua           ← love.audio (snd.* PS3 API, stream only).
│       ├── keyboard.lua        ← love.keyboard (pad.* API).
│       ├── timer.lua           ← love.timer (sys.TimerUsleep).
│       ├── whileloop.lua       ← Per-frame hooks + XMB callback.
│       └── event.lua           ← love.event.
└── tests/
    ├── run_all.lua             ← Entry point: lua tests/run_all.lua (from project root).
    ├── runner.lua              ← Minimal test framework (dofile it for a fresh instance).
    ├── mock_common.lua         ← Backend-agnostic mock + __rec native-call recorder.
    ├── mock_onelua.lua         ← OneLua native API (lowercase image/screen/draw/…).
    ├── mock_lppvita.lua        ← lpp-vita native API — encodes real arg orders.
    ├── mock_ps3.lua            ← PS3 native API (permissive stubs).
    ├── setup.lua               ← Loads common + backend mock per __MODE
    │                             ("OneLua" | "PSP" | "lpp-vita" | "PS3").
    ├── mock_platform.lua       ← Back-compat shim (OneLua mode) for legacy tests.
    ├── fixtures/               ← Small files loaded by tests.
    ├── test_core.lua           ← core/util, core/transform, core/textwrap.
    ├── test_bootstrap.lua      ← core/loader, core/runtime, core/config.
    ├── test_primitives.lua     ← Shared primitive suite across all 4 backends.
    ├── test_text.lua           ← Text metrics + printf across all 4 backends.
    ├── test_math.lua
    ├── test_data.lua
    ├── test_thread.lua
    ├── test_window.lua
    ├── test_joystick.lua
    ├── test_filesystem.lua
    ├── test_graphics.lua
    ├── test_keyboard.lua
    ├── test_timer.lua
    └── test_audio.lua
```

---

## Boot sequence

1. The console OS loads `index.lua` (OneLua/lpp-vita) or `app.lua` (PS3), which sets `lv1lua.dataloc` and `lv1lua.mode` then calls `dofile("script.lua")`.
2. `script.lua` dofiles `core/loader.lua` (which defines `lv1lua.load`), then runs the core steps in order: `core/util`, `core/transform`, `core/textwrap` → `core/runtime` (platform detection, screen size, `love.*` namespace, `love.getVersion`) → `love-functions/thread` → `core/config` (`game/conf.lua`, `lv1luaconf`, `lv1lua.keyset`) → `core/modules` (backend + shared modules) → `core/require`.  It then seeds the RNG, loads `game/main.lua`, calls `love.load()`, wires `core/callbacks`, and enters `while lv1lua.running do … end`.
3. Each iteration calls `lv1lua.draw()` → `lv1lua.update()` → `lv1lua.updatecontrols()`, all defined in the platform's `whileloop.lua`.

---

## Key global state

| Variable | Type | Meaning |
|---|---|---|
| `lv1lua` | table | Runtime state.  Never nil. |
| `lv1lua.mode` | string | `"OneLua"` / `"lpp-vita"` / `"PS3"` |
| `lv1lua.isPSP` | bool | `os.cfw` — true when running on PSP |
| `lv1lua.dataloc` | string | Prefix prepended to all asset paths |
| `lv1lua.screenWidth/Height` | number | PSP=480×272, Vita=960×544, PS3=720×480 |
| `lv1lua.current` | table | Active graphics state: font, color, bgcolor, canvas, blendMode |
| `lv1lua.current.colorRGBA` | `{r,g,b,a}` | Color in LÖVE 0–1 range |
| `lv1lua.current.color` | platform color | Converted 0–255 color object |
| `lv1lua.joystickState` | table | `{axes={lx,ly,rx,ry,l2,r2}, buttons={}, hats={"c"}}` — filled each frame |
| `lv1lua.keyset` | `{string×6}` | Button name mapping for circle/cross/etc → LÖVE names |
| `lv1luaconf` | table | Local config: `keyconf`, `imgscale`, `resscale` |
| `dt` | number | Delta time in seconds (global, set by the timer loop) |
| `love` | table | The entire LÖVE API namespace |

---

## Color system

LÖVE 11.x uses **0–1 floating point** for all colors.  Every platform SDK uses 0–255 integers.  The bridge is the local helper `_c255(r,g,b,a)` defined in each graphics module:

```lua
local function _c255(r,g,b,a)
    return math.floor(r*255+0.5), math.floor(g*255+0.5),
           math.floor(b*255+0.5), math.floor((a or 1)*255+0.5)
end
```

`lv1lua.current.colorRGBA` always holds the 0–1 values (used by `getColor()`).
`lv1lua.current.color` holds the platform-native color object (used by draw calls).

**Any game code using 0–255 colors will be wrong** — that's a game-side bug, not a wrapper bug.

---

## Drawable protocol

`love.graphics.draw` dispatches on the drawable argument type:

1. If `drawable._draw` exists → call `drawable:_draw(x, y, r, sx, sy, ox, oy)`.  This covers SpriteBatch, Text/TextBatch, ParticleSystem, Mesh.
2. If `drawable.imgData` exists → it is a wrapped image; use `drawable.imgData` for the platform blit call.
3. Otherwise → treat as a raw platform image handle.

When creating new drawable types, implement `_draw(self, x, y, r, sx, sy, ox, oy)`.

---

## Transform stack (OneLua/Vita graphics only)

```
_transformStack.stack   -- array of Transform objects
_transformStack.transform  -- accumulated result (recomputed when _dirty=true)
```

`love.graphics.push()` appends a new Transform; `pop()` removes it.
`translate/scale/rotate` modify the **top** entry of the stack and **compose in
local space** (accumulate): `translate` adds `scale*delta` to the offset, `scale`
multiplies the existing scale, `rotate` adds to the angle. (This was fixed in the
Phase 1 work — do **not** revert to plain assignment; `translate(10,0)` then
`translate(5,0)` must equal `translate(15,0)`.) `updateTransform()` is called
lazily before any draw operation and multiplies the stack levels together.

PSP and lpp-vita transform functions are still no-ops (parity work pending); PS3
uses scale constants.

> **lpp-vita native arg-order gotcha.** `Graphics.drawLine`, `Graphics.fillRect`
> and `Graphics.fillEmptyRect` take **`(x1, x2, y1, y2, color)`** — the two X
> coordinates first, then the two Y — not `(x1,y1,x2,y2)`. This is verified
> against `lpp-vita/source/luaGraphics.cpp`. Passing love-order coordinates
> silently mis-renders on device; the `tests/mock_lppvita.lua` mock encodes the
> real order so a mistake fails in tests.

---

## Platform API cheat-sheet

### OneLua (Vita/PSP)
| Category | API prefix |
|---|---|
| Images | `image.load / blit / resize / rotate / fliph / flipv` |
| Screen | `screen.print / clear / flip / textwidth / textheight` |
| Drawing | `draw.fillrect / rect / line / circle` |
| Font | `font.load / setdefault` |
| Sound | `sound.load / play / stop / pause / vol / playing / looping / loop` |
| Input | `buttons.read / held / released / analoglx …` |
| Color | `color.new(r,g,b,a)` (0–255) |
| Timer | `timer.new() → t:time()/reset()/start()` |
| Files | `files.exists / mkdir / delete / list` |
| OS | `os.delay / os.ram / os.totalram / os.cfw / os.language / os.nick` |

### lpp-vita
| Category | API prefix |
|---|---|
| Graphics | `Graphics.loadImage / drawImage / fillRect / fillCircle / drawLine` |
| Font | `Font.load / Font.setPixelSizes / Font.print / Font.getTextSize` |
| Sound | `Sound.open / Sound.play / Sound.close / Sound.setVolume` |
| Input | `Controls.read / Controls.check / Controls.getLeftX … / Controls.getEnterButton` |
| Color | `Color.new(r,g,b,a)` (0–255) |
| Timer | `Timer.new / Timer.getTime / Timer.reset / Timer.delay` |
| System | `System.doesFileExist / doesDirExist / listDirectory / createDirectory / deleteFile / getLanguage / getUsername` |

### PS3 Lua Player
| Category | API |
|---|---|
| Graphics | `InitGFX / FlipGFX / StartGFX / DrawText / BlitToScreen / surface():LoadIMG / setRectPos` |
| Sound | `snd.Init / SetVoice / PlayVoice / StopVoice / FreeVoice / SetVolumeBGMusic` |
| Input | `pad.circle/cross/triangle/square/L1/R1/up/down/left/right/select/start/L3/R3/lx/ly/rx/ry (0)` |
| System | `sys.TimerUsleep / UtilRegisterCallback / UtilCheckCallback / SYSUTIL_EXIT_GAME` |

---

## Running the tests

Tests run on a standard desktop Lua 5.3+ interpreter.  They do **not** require any console SDK.

```bash
# From the project root:
lua tests/run_all.lua
```

Each test file can also be run in isolation:

```bash
lua tests/test_math.lua
lua tests/test_graphics.lua
# etc.
```

### Test architecture (multi-backend)

- `tests/runner.lua` — Returns a fresh test-runner table each time it is `dofile`d.  Methods: `describe(name, fn)`, `it(desc, fn)`, `eq/near/ok/nok/istype/inrange`, `summary() → failcount`.
- `tests/mock_common.lua` — Backend-agnostic mock: `lv1lua`, `lv1luaconf`, a **fresh** `love` namespace, the VFS `files`, `os.*` extensions, input stubs, and the **native-call recorder** `__rec` (`__rec.reset()`, `__rec.log(name,...)`, `__rec.last(name)`, `__rec.all/count(name)`). Re-dofile'ing it resets all state, so one process can exercise every backend.
- `tests/mock_onelua.lua` / `tests/mock_lppvita.lua` / `tests/mock_ps3.lua` — Per-backend native APIs. **The lpp-vita mock encodes the real native arg orders** (see the gotcha above), and records draw/primitive calls into `__rec` so wrong-order bugs fail.
- `tests/setup.lua` — Loads `mock_common` then the backend mock for the global `__MODE` (default `"OneLua"`). Set `__MODE` before dofiling it to target a backend.
- `tests/mock_platform.lua` — Back-compat shim: `dofile("tests/setup.lua")` in OneLua mode. Existing single-backend tests keep using it.
- Each test file: `dofile("tests/runner.lua")`, then `dofile("tests/mock_platform.lua")` (or `setup.lua` with a chosen `__MODE`), then the module under test, then cases, then `return T.summary()`.
- `tests/test_primitives.lua` — Runs the shared primitive suite under **all three backends** and asserts the lpp-vita native arg order. Model for future backend-parametrised tests.
- `tests/run_all.lua` — `dofile`s each test file in sequence, accumulates failures, exits `0`/`1`.
- **CI:** `.github/workflows/ci.yml` runs `lua tests/run_all.lua` on lua 5.1 / 5.3 / 5.4 / luajit.

Coverage: `love.math`, `love.data`, `love.thread`, `love.window`, `love.joystick`, `love.filesystem`, `love.graphics`/`keyboard`/`timer`/`audio` (OneLua), plus multi-backend primitives (OneLua + lpp-vita + PS3).

To add a backend-specific test, dofile `setup.lua` with the right `__MODE`, load that backend's module, and assert against `__rec`. Extend the per-backend mock if a native call is missing.

---

## Known limitations and stubs

| Feature | Status |
|---|---|
| Canvas (offscreen rendering) | Stub — `renderTo(fn)` just calls fn(); no actual texture |
| Shader / GLSL | Stub — object exists but no code runs |
| Mesh | Stub — object exists, draw is no-op |
| love.graphics.polygon fill | Fan approximation (not scanline); wrong for concave polygons |
| PS3 graphics primitives | Stubs — PS3 SDK details unconfirmed |
| love.data.hash | Returns zeroed bytes of correct length; no real crypto |
| love.data.compress/decompress | Pass-through; no compression |
| love.timer.step | No-op |
| love.audio (OneLua) | Only 2 simultaneous channels (channel 1 = static, channel 2 = stream) |
| love.audio (PS3) | Stream only |
| Transforms (PSP/lpp-vita/PS3) | No-ops or approximations |

---

## Coding conventions

- **No comments by default.**  Only add a comment when the WHY is non-obvious (a hidden constraint, SDK quirk, or workaround for a specific bug).
- **No global leaks.** Every temporary variable inside a function must be `local`.
- **Color 0–1 everywhere** in the public API.  Convert with `_c255` only at the moment of making a platform draw call.
- **Drawable protocol**: implement `_draw(self, x, y, r, sx, sy, ox, oy)` for any object that `love.graphics.draw` should accept.
- **Button maps instead of if-elseif chains**.  See `whileloop.lua` for the pattern.
- **Shared modules** (`math.lua`, `data.lua`, `window.lua`, `joystick.lua`, `filesystem.lua`, `system.lua`, `thread.lua`) must not reference any platform-specific global.  They depend only on `lv1lua.*` and standard Lua.
- **Platform modules** (`OneLua/`, `lpp-vita/`, `PS3/`) may reference SDK globals freely but must never import from each other.

---

## Rules for AI agents

Read before committing anything.

- **Commit authorship is fixed.** Every commit and push must be authored solely by
  `Legendary Redfox <legendaryredfox.dev@gmail.com>`. Set it explicitly:
  `git commit --author="Legendary Redfox <legendaryredfox.dev@gmail.com>"`.
- **No AI trailer (no-ai-trailing).** Never add `Co-Authored-By: Claude`, "Generated
  with", or any AI attribution line to commit messages, PR bodies, or code.
- **No em-dashes.** Do not use the em-dash character in prose, docs, code comments,
  or commit messages. Use a comma, parentheses, a colon, or reword the sentence.
- **Never commit on `master` directly.** Branch first (`fix/...`, `feat/...`).
- **Test-first for behaviour changes.** Add a test that fails before the fix and
  passes after. Run the full suite (`lua tests/run_all.lua`) before every commit;
  it must be green on lua 5.1 and 5.4 at minimum.
- **LuaJIT / Lua 5.1 compatible.** The wrapper runs on the console SDKs' Lua. No
  5.3+ integer ops (`//`, `&`, `|`, `<<`, `>>`), no `<const>`/`<close>`, no
  `math.type`. Use `table.unpack or unpack`.
- **Keep backends independent.** Shared modules never touch platform globals;
  platform modules never import from each other.
- **Update `Implemented.md`** whenever you change API coverage or a documented
  limitation.
- One logical change per commit, Conventional Commits subject
  (`fix(scope): …`, `feat(scope): …`, `test: …`).

---

## Common tasks

### Adding a new love.graphics function
1. Add it to all three platform graphics files (and/or the PSP file).
2. If it is a stub, make it return the correct type so call-sites don't crash.
3. Update `Implemented.md`.

### Adding a new shared module
1. Create `LOVE-WrapLua/<module>.lua`.
2. Initialise its namespace in `script.lua` (`love.<module> = {}`).
3. Add a `dofile` line in `script.lua` after `system.lua` and before `game/main.lua`.
4. Add unit tests in `tests/test_<module>.lua` and register in `tests/run_all.lua`.

### Adding a new platform
1. Create `LOVE-WrapLua/<platform>/` with `graphics.lua`, `audio.lua`, `keyboard.lua`, `timer.lua`, `whileloop.lua`, `event.lua`.
2. Extend `lv1lua.mode` detection in `script.lua`.
3. Add screen dimensions to the platform detection block in `script.lua`.

### Changing the key layout
Edit `lv1lua.keyset` in `script.lua`.  The six entries map to: circle, cross, triangle, square, L, R.  `lv1lua.keyset[1]` is always the confirm button.

---

## File not to touch

| File | Reason |
|---|---|
| `game/libraries/anim8.lua` | Unmodified upstream library |
| `LOVE-WrapLua/Vera.ttf` | Default font binary |
