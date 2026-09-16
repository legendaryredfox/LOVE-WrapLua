# LOVE-WrapLua — Implemented API (LÖVE 11.5)

> Platform keys: **OL** = OneLua (Vita), **PSP** = PSP (graphics_psp), **LPP** = lpp-vita, **PS3** = PS3

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
| newImage(filename, settings) | ✓ | ✓ | ✓ | ✓ |
| newQuad(x,y,w,h,sw,sh or img) | ✓ | ✓ | ✓ | ✓ |
| draw(drawable, …) | ✓ | ✓ quad sub-rect + scale/flip via a cached copy, source never mutated | ✓ quad + rotation + scale via drawImageExtended | ✓ position only (quad accepted but ignored) |
| setColor(r,g,b,a) **0–1 range** | ✓ | ✓ | ✓ | ✓ |
| getColor() | ✓ | ✓ | ✓ | ✓ |
| setBackgroundColor | ✓ | ✓ | ✓ | ✓ |
| getBackgroundColor | ✓ | ✓ | ✓ | ✓ |
| clear(r,g,b,a) | ✓ | ✓ | stub | stub |
| setBlendMode / getBlendMode | stub | stub | stub | stub |
| setLineWidth / getLineWidth | ✓ | ✓ | ✓ | ✓ |
| setLineStyle / getLineStyle | stub | stub | stub | stub |
| setLineJoin / getLineJoin | stub | stub | stub | stub |
| setPointSize / getPointSize | stub | stub | stub | stub |
| newFont(file, size) | ✓ | ✓ | ✓ | ✓ |
| setFont / getFont | ✓ | ✓ | ✓ | ✓ |
| setNewFont | ✓ | ✓ | ✓ | ✓ |
| print(text, x, y) | ✓ | ✓ | ✓ | ✓ |
| printf(text, x, y, wrap, align) | ✓ | ✓ | ✓ | ✓ |
| rectangle(mode, x,y,w,h) | ✓ | ✓ | ✓ | stub |
| circle(mode, x,y,r) | ✓ | ✓ | ✓ | stub |
| ellipse(mode, x,y,rx,ry) | ✓ | ✓ | ✓ | stub |
| polygon(mode, vertices) | ✓ (fill≈line) | ✓ | ✓ | stub |
| arc(mode, type, x,y,r,a1,a2) | ✓ | ✓ | ✓ | stub |
| line(…) | ✓ | ✓ | ✓ | stub |
| points(…) | ✓ | ✓ | ✓ | stub |
| push / pop | ✓ | stub | ✓ | stub |
| translate / scale / rotate | ✓ | stub | ✓ | stub |
| shear | stub | stub | stub | stub |
| origin / reset | ✓ | ✓ | ✓ | ✓ |
| applyTransform / replaceTransform | ✓ | — | ✓ | — |
| transformPoint / inverseTransformPoint | ✓ | — | ✓ | — |
| setScissor / getScissor / intersectScissor | ✓ | stub | ✓ software reject | stub |
| stencil / setStencilTest / getStencilTest | stub | stub | stub | stub |
| setDefaultFilter / getDefaultFilter | ✓ | ✓ | stub | stub |
| getDimensions / getWidth / getHeight | ✓ | ✓ | ✓ | ✓ |
| isActive / present | ✓ | ✓ | ✓ | ✓ |
| captureScreenshot | stub | stub | stub | stub |
| newCanvas(w, h) | stub | stub | stub | stub |
| setCanvas / getCanvas | stub | stub | stub | stub |
| newShader / setShader / getShader | stub | stub | stub | stub |
| newSpriteBatch(img, max, usage) | ✓ | ✓ | ✓ | ✓ |
| newText(font, text) / newTextBatch | ✓ | ✓ | ✓ | ✓ |
| newMesh | stub | stub | stub | stub |
| newParticleSystem | ✓ (basic) | — | — | — |
| getStats / getRendererInfo | ✓ | ✓ | ✓ | ✓ |
| getSystemLimits / getSupported | ✓ | — | — | — |
| isGammaCorrect | ✓ | — | — | — |

---

## love.timer

| Function | All platforms |
|---|---|
| getTime() | ✓ |
| getDelta() | ✓ |
| getFPS() | ✓ |
| getAverageDelta() | ✓ |
| sleep(seconds) | ✓ |
| step() | stub (no-op) |

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

| Function | OL | LPP | PS3 |
|---|---|---|---|
| newSource(file, type) | ✓ | ✓ | ✓ (stream only) |
| play / stop / pause / resume | ✓ | ✓ | ✓ |
| getVolume / setVolume (global) | ✓ | stub | ✓ |
| getActiveSourceCount | ✓ | ✓ | ✓ |
| isEffectsSupported | stub | stub | stub |

### Source object methods
`play`, `stop`, `pause`, `resume`, `getVolume`, `setVolume`, `setLooping`, `isPlaying`, `isLooping`, `isStopped`, `isPaused`, `clone`, `seek`, `tell`, `getDuration`, `getType`

---

## love.filesystem

| Function | Notes |
|---|---|
| read / write / append | ✓ |
| isFile / isDirectory | ✓ |
| getInfo(file, filtertype) | ✓ |
| load | ✓ |
| remove | ✓ |
| createDirectory | ✓ |
| getDirectoryItems | ✓ |
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
| hash | stub (zeroed bytes) |
| compress / decompress | stub (pass-through) |
| newByteData / newDataView | ✓ |
| pack / unpack | ✓ (requires Lua 5.3) |
| getSize | ✓ |

---

## love.system

| Function | Notes |
|---|---|
| getOS() | returns "LOVE-WrapLua" |
| getLanguage | ✓ |
| getUsername | ✓ |

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

## Known Limitations

- **polygon fill** uses line-fan approximation (not scanline fill)
- **Canvas** is a stub — no actual offscreen rendering
- **Shader** is a stub — no GLSL support
- **Mesh** is a stub
- **love.graphics.rotate/translate/scale** only fully functional on OneLua/Vita
- **Audio**: OneLua supports only 2 simultaneous channels; PS3 supports stream only
- **love.timer.sleep** on lpp-vita busy-waits if `Timer.delay` is unavailable
- **love.data.hash** returns zeroed bytes (no crypto library)
- **love.data.compress/decompress** are pass-through
- PS3 graphics primitives (rectangle, circle, etc.) are stubs pending SDK confirmation
- Color is **0–1 range** (LÖVE 11.x standard) — code written for 0–255 must be updated
