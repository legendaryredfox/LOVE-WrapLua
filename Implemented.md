# LOVE-WrapLua — Implemented API (LÖVE 11.5)

> Platform keys: **OL** = OneLua (Vita), **PSP** = PSP (graphics_psp), **LPP** = lpp-vita, **PS3** = PS3
>
> Support tiers (`love._backend.tier`): **OL** and **PSP** are tier 1 (supported),
> **LPP** is tier 2 (partial), **PS3** is tier 3 (experimental: position-only
> draws, stubbed primitives, and RPCS3 cannot run it, so develop on desktop LÖVE
> and confirm on hardware). See the README "Support tiers" table.

---

## Callbacks

| Callback | OL | PSP | LPP | PS3 |
|---|---|---|---|---|
| love.load | ✓ | ✓ | ✓ | ✓ |
| love.update(dt) | ✓ | ✓ | ✓ | ✓ |
| love.draw | ✓ | ✓ | ✓ | ✓ |
| love.keypressed(key, scancode, isrepeat) once per press | ✓ | ✓ | ✓ | ✓ |
| love.keyreleased(key, scancode) once per release | ✓ | ✓ | ✓ | ✓ |
| love.textinput | stub | stub | stub | stub |
| love.quit | ✓ | ✓ | ✓ | ✓ |
| love.mousepressed | OL-Vita only | — | — | — |
| love.gamepadpressed | routed via keypressed | ✓ | ✓ | ✓ |
| love.gamepadreleased | routed via keyreleased | ✓ | ✓ | ✓ |
| love.focus / visible / resize | stub | stub | stub | stub |
| love.lowmemory / threaderror | stub | stub | stub | stub |

---

## love (top-level)

- `love.getVersion()` → `11, 5, 0, "Mysterious Mysteries"`

---

## love.graphics

| Function | OL | PSP | LPP | PS3 |
|---|---|---|---|---|
| newImage(filename, settings) | ✓ warns if >512 | ✓ warns if >512 / NPOT | ✓ warns if >1024 | ✓ no validation |
| newQuad(x,y,w,h,sw,sh or img) | ✓ warns if >512 | ✓ warns if >512 / NPOT | ✓ warns if >1024 | ✓ no validation |
| setTextureInset / getTextureInset | ✓ | ✓ | ✓ | — |
| draw(drawable, …) | ✓ | ✓ quad sub-rect + scale/flip via a cached copy, source never mutated | ✓ quad + rotation + scale via drawImageExtended | ✓ position only (quad accepted but ignored) |
| setColor(r,g,b,a) **0–1 range** | ✓ | ✓ | ✓ | ✓ |
| getColor() | ✓ | ✓ | ✓ | ✓ |
| setBackgroundColor | ✓ | ✓ | ✓ | ✓ |
| getBackgroundColor | ✓ | ✓ | ✓ | ✓ |
| clear(r,g,b,a) | ✓ | ✓ | no-op (frame loop clears) | no-op (frame loop clears) |
| setBlendMode / getBlendMode | tracked, never applied | tracked | tracked | tracked |
| setLineWidth / getLineWidth | ✓ | ✓ | ✓ | ✓ |
| setLineStyle / getLineStyle | stub | stub | stub | stub |
| setLineJoin / getLineJoin | stub | stub | stub | stub |
| setPointSize / getPointSize | stub | stub | stub | stub |
| newFont(file, size) | ✓ TTF, cached per face+size | ✓ PGF system face only, size varies | ✓ TTF, cached per face+size | ✓ no native font, metrics estimated |
| setFont / getFont | ✓ | ✓ | ✓ | ✓ |
| setNewFont | ✓ | ✓ | ✓ | ✓ |
| print(text, x, y) | ✓ | ✓ | ✓ | ✓ |
| printf(text, x, y, wrap, align) | ✓ | ✓ | ✓ | ✓ |
| rectangle(mode, x,y,w,h) | ✓ | ✓ | ✓ | stub |
| circle(mode, x,y,r) | ✓ | ✓ | ✓ | stub |
| ellipse(mode, x,y,rx,ry) | ✓ | ✓ | ✓ | stub |
| polygon(mode, vertices) | ✓ scanline fill (convex + concave) | ✓ scanline fill | ✓ scanline fill | stub |
| arc(mode, type, x,y,r,a1,a2) | ✓ | ✓ | ✓ | stub |
| line(…) | ✓ | ✓ | ✓ | stub |
| points(…) | ✓ | ✓ | ✓ | stub |
| push / pop | ✓ | stub (identity, never nil) | ✓ | stub (identity, never nil) |
| translate / scale / rotate | ✓ images **and** primitives | stub | ✓ images **and** primitives | stub |
| shear | stub | stub | stub | stub |
| origin / reset | ✓ | ✓ | ✓ | ✓ |
| applyTransform / replaceTransform | ✓ | stub | ✓ | stub |
| transformPoint / inverseTransformPoint | ✓ | identity | ✓ | identity |
| setScissor / getScissor / intersectScissor | ✓ | stub | ✓ software reject | stub |
| stencil / setStencilTest / getStencilTest | stub | stub | stub | stub |
| setDefaultFilter / getDefaultFilter | ✓ reaches the native filter | tracked only | tracked only | tracked only |
| getDimensions / getWidth / getHeight | ✓ | ✓ | ✓ | ✓ |
| isActive / present | ✓ | ✓ | ✓ | ✓ |
| captureScreenshot | stub | stub | stub | stub |
| newCanvas(w, h) | stub (`canvas=false`) | stub | stub | stub |
| setCanvas / getCanvas | stub (draws to screen) | stub | stub | stub |
| newShader / setShader / getShader | stub | stub | stub | stub |
| newSpriteBatch(img, max, usage) | ✓ | ✓ quads honoured, no rotation | ✓ | ✓ position only |
| newText(font, text) / newTextBatch | ✓ | ✓ | ✓ | ✓ |
| newMesh | stub | stub | stub | stub |
| newParticleSystem | ✓ (basic) | — | — | — |
| getStats / getRendererInfo | ✓ shared stat table (all fields present, all zero) | ✓ | ✓ | ✓ |
| getSystemLimits / getSupported | ✓ | ✓ | ✓ | ✓ (from central capability table) |
| isGammaCorrect | ✓ | — | — | — |

### Font object methods

One shared Font implementation (`core/font.lua`) on every backend; only
measuring and face loading are native.

| Method | OL | PSP | LPP | PS3 |
|---|---|---|---|---|
| getWidth(text) | ✓ native `screen.textwidth` | ✓ native `screen.textwidth` | ✓ native `Font.getTextWidth` | estimate: glyphs × size × 0.6 |
| getHeight / getBaseline / getAscent | ✓ = requested size | ✓ | ✓ | ✓ |
| getDescent | 0 | 0 | 0 | 0 |
| getLineHeight / setLineHeight | ✓ stored, used by printf | ✓ | ✓ | ✓ |
| getWrap(text, width) | ✓ | ✓ | ✓ | ✓ |
| type / typeOf / release | ✓ | ✓ | ✓ | ✓ |
| hasGlyph / getKerning / setFallbacks / getDPIScale | stub (`true` / `0` / no-op / `1`) | stub | stub | stub |
| getFilter / setFilter | reports the default filter; set is a no-op | same | same | same |

printf line spacing is LOVE's `getHeight() * getLineHeight()` on all four
backends, and wrapping is measured with the font itself, never by byte count.

---

## love.timer

| Function | All platforms |
|---|---|
| getTime() | ✓ |
| getDelta() | ✓ the fixed update slice the current `love.update` was called with |
| getFPS() | ✓ measured render rate (rolling mean of the last 30 frames) |
| getAverageDelta() | ✓ mean measured frame time |
| sleep(seconds) | ✓ |
| step() | ✓ returns the last frame time; the main loop does the measuring |

Updates run on a shared fixed-timestep accumulator (`core/timestep.lua`):
`love.update` is called in `1/lv1luaconf.updaterate` slices (default 60/s) and
the leftover time carries into the next frame, so game speed no longer follows
the render rate. `lv1luaconf.maxframeskip` (default 5) caps the catch-up after a
stall. `lv1luaconf.updaterate = "variable"` restores desktop LÖVE's
one-update-per-frame behaviour. The PS3 Lua Player exposes no timer, so that
backend assumes one slice per frame.

---

## love.keyboard

| Function | All platforms |
|---|---|
| isDown(key) | ✓ |
| isScancodeDown | ✓ |
| hasKeyRepeat / setKeyRepeat | ✓ off by default; when on, repeats after 0.4s at 0.05s intervals |
| hasTextInput | stub |
| getKeyFromScancode / getScancodeFromKey | ✓ (identity) |
| showTextInput / setTextInput | ✓ |

---

## love.audio

One shared Source implementation (`core/audio.lua`) on every backend; each
backend supplies only its native hooks.

| Function | OL / PSP | LPP | PS3 |
|---|---|---|---|
| newSource(file, type) | ✓ (non-MP3 extensions are mapped to `.mp3`) | ✓ | ✓ stream only; a `static` source loads nothing and stays silent |
| play / stop / pause / resume | ✓ | ✓ | ✓ |
| play/stop/pause/resume with no argument | ✓ all sources (`pause()` returns what it paused) | ✓ | ✓ |
| getVolume / setVolume (global) | ✓ scales every source | ✓ | ✓ |
| getActiveSourceCount / getSourceCount | ✓ | ✓ | ✓ |
| isEffectsSupported / getMax*Effects | `false` / `0` | same | same |
| setPosition / setOrientation / setDistanceModel (listener) | stub (mono output) | stub | stub |
| Simultaneous voices | 2 (1 static + 1 stream) | 8 | 1 (background voice) |

### Source object methods

| Method | Notes |
|---|---|
| play / stop / pause / resume | ✓ native on every backend |
| isPlaying / isStopped / isPaused | ✓ real paused state (was always `false`) |
| setVolume / getVolume | ✓ 0–1, scaled by the master volume |
| setLooping / isLooping | ✓ (OneLua toggles the native loop flag) |
| tell(unit) | ✓ timed from `love.timer.getTime` across play/pause/resume/seek (no SDK here reports a position); `"samples"` assumes 44100 Hz |
| seek(position, unit) | moves the reported position; only lpp-vita builds that expose `Sound.setPosition` really jump, so audio keeps playing where it was |
| setPitch / getPitch | tracked and applied to the timed position; only used natively where the SDK exposes a pitch call (probed) |
| getDuration | native where exposed, else read from a WAV header, else `0` |
| clone | ✓ copies volume, pitch and looping |
| type / typeOf / release | ✓ |
| getChannelCount / setPosition / setRelative | stub (mono console output) |

---

## love.filesystem

| Function | Notes |
|---|---|
| read / write / append | ✓ save directory first, then the game directory |
| isFile / isDirectory | ✓ a directory is no longer reported as a file (native probe, else "exists but cannot be read as bytes") |
| getInfo(file, filtertype) | ✓ real `size` in bytes; `type` distinguishes file and directory; `modtime` is always 0 (no SDK here exposes a file date) |
| Quad(x, y, w, h, image) | ✓ texture dimensions come from the image on all four backends |
| load | ✓ |
| remove | ✓ |
| createDirectory | ✓ |
| getDirectoryItems | ✓ merges the game and save directories, drops duplicates, sorted |
| lines | ✓ |
| newFile | ✓ |
| newFileData | ✓ |
| mount / unmount | stub |
| getIdentity / setIdentity | ✓ |
| getWorkingDirectory / getRealDirectory | ✓ |
| getUserDirectory / getSaveDirectory | ✓ |
| isFused | ✓ (always true) |

---

## love.math

| Function | Notes |
|---|---|
| random / setRandomSeed | ✓ own generator, not Lua's `math.random`; `setRandomSeed(low, high)` uses both words |
| getRandomSeed | ✓ returns the two state words |
| randomNormal | ✓ Box-Muller |
| noise(x,y,z,w) | ✓ Perlin 1D-4D, normalized 0–1; loading does not reseed Lua's RNG |
| newTransform | ✓ full 2D affine |
| newBezierCurve | ✓ |
| newRandomGenerator | ✓ L'Ecuyer combined generator: period ≈2.3e18, exact in a double on Lua 5.1–5.4 and LuaJIT. `getState` returns both words as `"s1,s2"` |
| isConvex | ✓ |
| triangulate | ✓ ear-clip |
| colorFromBytes / colorToBytes | ✓ |
| gammaToLinear / linearToGamma | ✓ |

---

## love.window

All functions present. Console window is always fullscreen; `setMode` is a no-op.

Key implemented: `getDimensions`, `getWidth`, `getHeight`, `getTitle`, `setTitle`, `getMode`, `hasFocus`, `isVisible`, `isOpen`, `getSafeArea`, `getDPIScale`, `showMessageBox` (stub).

---

## love.joystick

| Function | Notes |
|---|---|
| getJoysticks() | returns 1 controller |
| getJoystickCount() | returns 1 |
| Joystick:getAxis(n) | ✓ axes 1–4 (lx,ly,rx,ry) + 5–6 (L2,R2 if available) |
| Joystick:getAxes() | ✓ |
| Joystick:isDown(n) | ✓ raw button index |
| Joystick:isGamepadDown(name) | ✓ LÖVE gamepad name |
| Joystick:getGamepadAxis(name) | ✓ leftx/lefty/rightx/righty |
| Joystick:getHat / getName / getID | ✓ |
| Joystick:isVibrationSupported | false |

---

## love.data

| Function | Notes |
|---|---|
| encode / decode | ✓ base64 + hex |
| hash | ✓ md5/sha1/sha224/256/384/512 (vendored sha2.lua), raw-byte digest |
| compress / decompress | ✓ deflate + zlib (vendored LibDeflate); gzip/lz4 fall back to deflate |
| newByteData / newDataView | ✓ |
| pack / unpack | ✓ (requires Lua 5.3) |
| getSize | ✓ |

---

## love.touch / love.mouse (Vita, OneLua only)

Loaded on the Vita whatever button layout is configured; PSP, lpp-vita and PS3
do not define them.

| Function | Notes |
|---|---|
| love.touch.getTouches | ✓ returns the live touch ids |
| love.touch.getPosition(id) | ✓ front-panel coordinates of that touch; `0, 0` for an id that is not down |
| love.touch.getPressure(id) | ✓ `1` while the finger is down, else `0` |
| love.mouse.getX / getY / getPosition | ✓ the last touch position |
| love.mouse.isDown(button) | ✓ a touch is button 1 |
| love.mouse.setPosition / setVisible / setGrabbed / setRelativeMode | stub (no pointer to move or hide) |

---

## love.system

| Function | Notes |
|---|---|
| getOS() | returns "LOVE-WrapLua" |
| getLanguage | ✓ native on OneLua (`os.language`) and lpp-vita (`System.getLanguage`); `"en"` elsewhere |
| getUsername | ✓ native on OneLua (`os.nick`) and lpp-vita (`System.getUsername`); `""` elsewhere |
| getProcessorCount | ✓ from the capability table: Vita 4, PSP 1, PS3 2 |
| getPowerInfo | ✓ native on lpp-vita (percentage, charging, minutes→seconds); `"nobattery"` on PS3; `"unknown"` where the SDK exposes no battery call (OneLua) |
| setClipboardText / getClipboardText | ✓ process-local: no console exposes a system clipboard, so the text is gone on exit |
| openURL | returns `false` (no SDK here hands a URL to a browser) |
| vibrate | no-op (no rumble motor on Vita/PSP, none exposed on PS3) |
| hasBackgroundMusic | returns `false` |

---

## love.thread (pseudo-threads via coroutines)

`newThread`, `getChannel`, `newChannel`, `getThread`, `getThreads`

Channel methods: `push`, `pop`, `peek`, `clear`, `hasRead`, `getCount`,
`supply`, `demand`, `performAtomic`

**Synchronous, by design.** There is no OS threading on these backends: a
thread runs as a coroutine when `start(...)` is called and finishes before
`start` returns, with its extra arguments forwarded into the chunk.
Consequently `Channel:supply` cannot block (it is an immediate push) and
`Channel:demand` is a non-blocking pop returning `nil` on an empty channel.
Do not write producer/consumer logic that relies on cross-thread blocking.

---

## Platform-specific callbacks

- `onLiveArea()` — Vita only, called when entering live area
- `onResume()` — Vita only, called on resume

---

## Emulator and renderer caveats

Emulators are dev convenience, not a validation target. Each backend records the
emulator it is usually tested on plus the areas that emulator gets wrong, in
`love._backend.emulator` and `love._backend.rendersensitive`
(`blendmode`, `framebufferread`, `texturefilter`, `savepersistence`).

| Backend | Emulator | Flagged as renderer-sensitive |
|---|---|---|
| OL | Vita3K | blendmode, framebufferread, savepersistence |
| LPP | Vita3K | blendmode, framebufferread, savepersistence |
| PSP | PPSSPP | texturefilter, framebufferread |
| PS3 | RPCS3 (homebrew loading unreliable) | all four, nothing is confirmed |

- **Vita3K:** programmable blend and framebuffer reads are inaccurate and vary
  between OpenGL, Vulkan and MoltenVK (Vita3K #4109, #422); writes can be lost
  when the emulator closes (#3918, #3659).
- **PPSSPP:** linear filtering bleeds a row of texels from the opposite edge of a
  quad (#14977); framebuffer and texture sizing can differ from hardware (#3085).
  Use `love.graphics.setTextureInset(0.5)` or nearest filtering.
- **RPCS3:** homebrew loading is minimal (#18997), so the PS3 backend cannot be
  validated there. Use desktop LÖVE for logic and real hardware for output.

The full per-area dev target matrix (real hardware vs Vita3K GL/Vulkan vs PPSSPP
vs RPCS3) is in the README under "Testing and validation targets".

---

## Known Limitations

- **Canvas** (offscreen render target) is unsupported on every backend today;
  `getSupported().canvas` is `false`. `newCanvas`/`setCanvas`/`renderTo` exist so
  games do not crash, but `renderTo` draws straight to the screen. The native
  paths, per backend:
  - **lpp-vita / vita2d:** `createImage` already returns a rendertarget texture
    and `vita2d_create_empty_texture_rendertarget(w,h,fmt)` exists, but lpp-vita
    exposes no Lua "bind draw target" (only the fixed rescaler FBO). A real
    Canvas is a small, concrete native patch upstream — expose a bind around the
    existing vita2d rendertarget call — not an architectural wall.
  - **PS3 / tiny3D:** `cloned67/tiny3d` (and `Dnawrkshp/mini2d`) expose
    scene-to-texture surfaces, so a PS3 Canvas is reachable once the backend
    moves onto tiny3D (tracked under T6.6).
  - **OneLua (PSP + Vita):** no render target exposed by the SDK.
- **Shader** is a stub — no programmable pipeline exposed (`getSupported().shader`
  and `glsl3` are `false`). PS3 tiny3D pixel shaders are the first plausible real
  path (T6.6).
- **Texture limits** — `newImage`/`newQuad` validate the sheet against the
  backend's `getSystemLimits().texturesize` (512 on OneLua/PSP/PS3, 1024 on
  lpp-vita) and, on **PSP only**, against the GPU's power-of-two requirement. A
  violation logs a `[LOVE-WrapLua]` warning (once per distinct problem) instead
  of silently corrupting the texture — split an oversize spritesheet, and pad PSP
  sheets so both dimensions are powers of two (≤512). Warnings route through
  `lv1lua.warn` if you set it.
- **Quad edge-bleed** — `love.graphics.setTextureInset(px)` (wrapper extension,
  not stock LÖVE; default `0`) shrinks every quad's source rect by `px` texels
  per side so linear filtering stops sampling the neighbouring frame at a
  boundary (PPSSPP #14977). Use `0.5` for tightly-packed linear-filtered sheets;
  pixel art is better served by nearest filtering. Applied on OneLua/PSP/lpp-vita;
  PS3 draws position-only, so it is a no-op there.
- **Save durability** — `write`/`append` open, write and `close()` in one call,
  so those saves are always flushed. A long-lived `newFile` handle you leave open
  is tracked and closed automatically at `love.event.quit` (before the process
  exits), so a save is not lost when the app or emulator closes (Vita3K #3918 /
  #3659). Still, call `File:close()` yourself when done for the earliest flush.
- **Mesh** is a stub
- **love.graphics.rotate/translate/scale/push/pop** work on OneLua/Vita and
  lpp-vita (software transform stack); on PSP and PS3 they are no-ops
- **polygon fill** is a real even-odd scanline fill on OneLua/PSP/lpp-vita; PS3
  primitives remain stubs
- **Audio**: OneLua supports only 2 simultaneous channels; PS3 supports stream only
- **love.timer.sleep** on lpp-vita busy-waits if `Timer.delay` is unavailable
- **love.data.hash / compress / decompress** are real (pure-Lua vendored libs,
  slow on-device — cache results). `gzip`/`lz4` compression fall back to deflate
  and are not byte-compatible with those two desktop formats; `deflate`/`zlib` are.
- PS3 graphics primitives (rectangle, circle, etc.) are stubs pending SDK confirmation
- Color is **0–1 range** (LÖVE 11.x standard) — code written for 0–255 must be updated
