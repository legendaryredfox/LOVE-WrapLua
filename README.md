![Greetings](images/warudo.png)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-legendaryredfox-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/legendaryredfox)

# LOVE-WrapLua

A [LÖVE](https://love2d.org/) 11.5 compatibility layer for **PSP**, **PS Vita**, and **PS3**.
Drop your LÖVE game into `game/` and boot the wrapper — it re-implements the LÖVE
API on top of each console's native Lua SDK, so a game written against `love.*`
runs on the handheld/console without a real LÖVE runtime.

> **Scope.** This is a 2D subset of LÖVE aimed at homebrew hardware. GPU-heavy
> features (Canvas/render-to-texture, shaders, meshes) are stubbed — see
> [Known limitations](#known-limitations). If your game is sprite-based 2D, it
> should port with little or no change.

---

## Supported platforms

| Platform | Backend (`lv1lua.mode`) | Native SDK | Maturity |
|---|---|---|---|
| PS Vita | `OneLua` | [OneLua](http://onelua.x10.mx/) | Good |
| PSP | `OneLua` (PSP sub-mode) | OneLua | Good |
| PS Vita (alternative) | `lpp-vita` | [lpp-vita](https://github.com/Rinnegatamante/lpp-vita) | Partial |
| PS3 | `PS3` | Lua Player PS3 | Experimental |

The backend is selected automatically at boot (see [Entry points](#entry-points)).
PSP is detected at runtime via `os.cfw`.

---

## Quick start

1. **Add your game.** Copy your LÖVE project into `game/` (`main.lua`,
   optional `conf.lua`, and all assets).
2. **(Optional) configure the wrapper** by defining `lv1luaconf` *before* the
   wrapper boots — put it at the very top of `game/main.lua`:

   ```lua
   lv1luaconf = {
       keyconf  = "XB",    -- "XB" (Xbox layout), "XBA" (swapped confirm), "PS" (PlayStation layout), or "SE" (auto-detect system enter button)
       imgscale = false,   -- scale images to 75% (handy on the PSP's smaller screen)
       resscale = false,   -- scale all draw coordinates to 75%
   }
   ```
3. **(Optional) `game/conf.lua`.** A standard LÖVE `conf.lua` works; the wrapper
   reads `t.identity` (used for the save directory) and `t.window.title`.
4. **Build & deploy** for your target — see [Building & deploying](#building--deploying).

### Minimal game

`game/main.lua`:

```lua
local player

function love.load()
    player = {
        img = love.graphics.newImage("player.png"),
        x = 100, y = 100,
    }
end

function love.update(dt)
    local js = love.joystick.getJoysticks()[1]
    if js:isGamepadDown("dpleft")  then player.x = player.x - 120 * dt end
    if js:isGamepadDown("dpright") then player.x = player.x + 120 * dt end
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(player.img, player.x, player.y)
    love.graphics.print("Hello from LOVE-WrapLua", 10, 10)
end

-- Input: keypressed receives console button names; if you only implement
-- gamepadpressed, the wrapper routes button presses there automatically.
function love.gamepadpressed(joystick, button)
    if button == "start" then love.event.quit() end
end
```

Colours are LÖVE 11.x **0–1 floats** (`setColor(1, 1, 1)`), not 0–255.

---

## Building & deploying

The wrapper is just Lua + assets; packaging is done by the target SDK. Exact tool
versions change over time, so follow each SDK's current docs — the target-specific
notes below tell you which entry file and layout the wrapper expects.

### PS Vita — lpp-vita
- Entry point: **`index.lua`** (sets `lv1lua.mode = "lpp-vita"`, `dataloc = "app0:/"`).
- Package the project root (with `index.lua`, `script.lua`, `game/`, `LOVE-WrapLua/`)
  into a VPK using the lpp-vita loader / `vita-mksfoex` toolchain from the
  [lpp-vita releases](https://github.com/Rinnegatamante/lpp-vita/releases).
- Install the `.vpk` with VitaShell, launch from LiveArea.

### PS Vita / PSP — OneLua
- Boot path uses **`script.lua`** (OneLua sets `lv1lua.mode = "OneLua"` when no
  mode is preset; `dataloc = ""`).
- Run inside the OneLua interpreter, or build a standalone with OneLua's compiler.
  A prebuilt **`EBOOT.PBP`** (PSP) and **`oneFont.pgf`** are included as a
  starting point.
- PSP: place the EBOOT + project under `ms0:/PSP/GAME/LOVE-WrapLua/`.
- See the [OneLua](http://onelua.x10.mx/) docs for packaging specifics.

### PS3 — Lua Player PS3
- Entry point: **`app.lua`** (loads `script.lua`). Experimental; graphics
  primitives are largely stubbed pending SDK confirmation. Use desktop LÖVE +
  real hardware to validate game logic.

### Entry points

| File | Target | Purpose |
|---|---|---|
| `script.lua` | all | Bootstrap — sets up `love`, loads modules, runs the loop |
| `index.lua`  | lpp-vita | Sets mode + `dataloc`, then loads `script.lua` |
| `app.lua`    | PS3 | Loads `script.lua` |

---

## LÖVE 11.5 API coverage

See **[`Implemented.md`](Implemented.md)** for the full per-backend matrix.
High-level summary:

- **love.graphics** — images, quads, 2D primitives, fonts, print/printf,
  SpriteBatch, Text/TextBatch, ParticleSystem, transform stack, scissor. Blend
  mode, Canvas, Shader, Mesh are stubs.
- **love.audio** — newSource, play/stop/pause/resume, volume, looping, clone.
- **love.keyboard** — isDown, isScancodeDown, showTextInput.
- **love.joystick** — getJoysticks, axis/button/hat state, gamepad mapping.
- **love.timer** — getTime, getDelta, getFPS, sleep.
- **love.filesystem** — read/write/append, getInfo, lines, newFile,
  newFileData, directory helpers.
- **love.math** — random, noise (Perlin), newTransform (2D affine),
  newBezierCurve, triangulate, colorFromBytes/ToBytes.
- **love.data** — encode/decode (base64, hex), ByteData, DataView, pack/unpack.
- **love.window** — dimensions, title, getMode (always fullscreen on consoles).
- **love.thread** — channels + synchronous pseudo-threads (see limitations).
- **love.system** — getOS, getLanguage, getUsername.
- **love.touch / love.mouse** — Vita front touchscreen (OneLua only).

---

## Input model

- Console buttons arrive through `love.keypressed(key)` / `love.keyreleased(key)`
  using names like `"a"`, `"b"`, `"start"`, `"dpleft"`, `"leftshoulder"`.
- If your game only defines `love.gamepadpressed` / `love.gamepadreleased`, the
  wrapper forwards presses to them using the first joystick.
- `love.joystick.getJoysticks()[1]` always returns a connected virtual gamepad;
  use `:isGamepadDown(...)`, `:getGamepadAxis(...)`.
- `keyconf` picks the physical→logical button layout; `"SE"` auto-detects the
  system confirm button (circle vs cross) per region.

---

## Running the tests

Tests run on desktop Lua (5.1 / 5.3 / 5.4 / LuaJIT) — no console needed. They
currently exercise the **OneLua** backend via mocks.

```bash
lua tests/run_all.lua           # full suite
lua tests/test_math.lua         # a single suite
```

---

## Known limitations

Honest current state. Some items are wrapper stubs (hardware can't do it); a few
are bugs being tracked for fix.

**Platform stubs (by design):**
- **Canvas** — stub; `renderTo(fn)` runs `fn()` but there is no offscreen target.
  lpp-vita exposes render-target textures but no way to bind them as a draw
  target from Lua, so real RTT isn't possible without a native patch.
- **Shader / Mesh** — stubs; objects exist so call-sites don't crash, nothing renders.
- **Blend mode** — stub; only the platform default (alpha) is applied. Verify any
  blend-dependent look on real hardware, not on an emulator.
- **love.data.hash** — returns zeroed bytes of the right length (no crypto).
- **love.data.compress/decompress** — pass-through (no real compression); saves
  are **not** byte-compatible with desktop LÖVE.
- **love.thread** — pseudo-threads run **synchronously** on a coroutine (no real
  parallelism); a thread body that loops forever will hang the app. Channels
  support push/pop/peek/clear.
- **Polygon fill** — approximated with a centroid fan; correct only for convex
  shapes, and currently draws as outline on some backends.
- **Transforms** — full transform stack is OneLua/Vita only; on lpp-vita and PS3
  they are currently no-ops/approximations.
- **love.audio (OneLua)** — ~2 simultaneous channels; **(PS3)** — stream sources only.

**Known bugs (tracked, not yet fixed):**
- **lpp-vita spritesheets/quads** — the lpp-vita `draw` does not yet accept the
  quad form or rotation, so `love.graphics.draw(img, quad, ...)` (and thus most
  animation libraries) does not render correctly on that backend. Use the
  **OneLua** backend on Vita for spritesheet games until fixed.
- **lpp-vita line primitives** — line/polygon/circle-outline/ellipse/arc use the
  wrong native argument order and render skewed on that backend.

---

## Testing & validation targets

- **Game logic:** run your game on **desktop LÖVE 11.5** first — fastest iteration.
- **On device:** real PSP/Vita/PS3 hardware is the source of truth, especially for
  blend, timing, and save behaviour.
- **Emulators (dev convenience):** RetroArch (PSP/Vita cores), Vita3K, PPSSPP.
  Note that emulator rendering can differ from hardware (blend/framebuffer
  accuracy varies by OpenGL/Vulkan/MoltenVK backend), and some emulators may not
  flush saves on close — always confirm blend- and save-critical behaviour on
  real hardware.

---

## Constraints to keep in mind

- **PSP textures** must be power-of-two and ≤ 512×512. Split larger spritesheets.
- **Screen sizes:** PSP 480×272, PS3 720×480, Vita 960×544. Use
  `love.graphics.getDimensions()` rather than hardcoding.
- **Spritesheet edge bleed:** leave a 1px gutter between frames (Grid `border`)
  or use nearest filtering to avoid neighbouring frames bleeding in.

---

## Project structure

```
game/           ← your LÖVE game lives here (main.lua, conf.lua, assets)
script.lua      ← wrapper bootstrap
index.lua       ← lpp-vita entry point
app.lua         ← PS3 entry point
LOVE-WrapLua/
  math.lua / filesystem.lua / data.lua     ← shared pure-Lua modules
  window.lua / joystick.lua / system.lua
  love-functions/thread.lua
  OneLua/       ← Vita + PSP platform modules
  lpp-vita/     ← lpp-vita platform modules
  PS3/          ← PS3 Lua Player platform modules
tests/          ← unit tests (desktop Lua)
Implemented.md  ← detailed per-backend API coverage table
AGENTS.md       ← AI agent orientation guide
```

---

## Notes

- Tested primarily on PSP and Vita; PS3 support is least complete.
- Sample assets are from [Kenney](https://kenney.nl/assets/scribble-dungeons) and
  [game-endeavor](https://game-endeavor.itch.io/mystic-woods) — go support them.
- Hobby project; updated when time allows.

---

## Credits and thanks

- [OneLua](http://onelua.x10.mx/) team — for their contributions to the PSP/Vita
  homebrew community.
- [Rinnegatamante](https://github.com/Rinnegatamante/lpp-vita) — lpp-vita.
- [LukeZGD](https://github.com/LukeZGD/LOVE-WrapLua) — original author of
  LOVE-WrapLua; this is a continuation of that archived project.
- [DDLC-LOVE](https://github.com/LukeZGD/DDLC-LOVE/) — the project that originally
  used this wrapper.
