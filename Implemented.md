# LOVE-WrapLua: implemented API (LÖVE 11.5)

Columns: **OL** = OneLua on PS Vita, **PSP** = OneLua on PSP, **LPP** = lpp-vita,
**PS3** = PS3 Lua Player (tiny3D), **3DS** = lpp-3ds.

Support tiers (`love._backend.tier`): OL and PSP are tier 1 (supported), LPP and
PS3 tier 2 (partial; RPCS3 cannot run the PS3 build, so confirm it on hardware),
the 3DS tier 3 (experimental: grounded in the lpp-3ds sources, not yet run on a
console). See the README "Support tiers" table.

Legend: ✓ = LÖVE behaviour, **tracked** = the value is stored and read back but
does not reach the hardware, **stub** = callable, does nothing, **none** = not
defined, so calling it errors.

---

## Callbacks

| Callback | OL | PSP | LPP | PS3 | 3DS |
|---|---|---|---|---|---|
| love.load / update(dt) / draw | ✓ | ✓ | ✓ | ✓ | ✓ |
| love.keypressed(key, scancode, isrepeat), once per press | ✓ | ✓ | ✓ | ✓ | ✓ |
| love.keyreleased(key, scancode), once per release | ✓ | ✓ | ✓ | ✓ | ✓ |
| love.gamepadpressed / gamepadreleased | routed from the key callbacks when the game defines no keypressed / keyreleased; the d-pad arrives as `dpup` / `dpdown` / `dpleft` / `dpright` | same | same | same | same |
| love.textinput | ✓ on-screen keyboard | ✓ on-screen keyboard | ✓ IME, fires when it closes | stub | stub |
| love.mousepressed / mousereleased / mousemoved | ✓ first finger, `istouch` true | none | none | none | none |
| love.touchpressed / touchmoved / touchreleased | ✓ front panel | none | none | none | none |
| love.quit | ✓ returning true cancels the quit | ✓ | ✓ | ✓ (an XMB exit or L3+R3 cannot be cancelled) | ✓ |
| love.threaderror | ✓ | ✓ | ✓ | ✓ | ✓ |
| love.focus / visible / resize / lowmemory / wheelmoved | stub | stub | stub | stub | stub |

---

## love (top level)

- `love.getVersion()` returns `11, 5, 0, "Mysterious Mysteries"`.
- `love._backend` is the capability record for the running backend
  (`core/capabilities.lua`): tier, limits, feature flags, emulator caveats.

---

## love.graphics

| Function | OL | PSP | LPP | PS3 | 3DS |
|---|---|---|---|---|---|
| newImage(filename) | ✓ warns above 512 | ✓ warns above 512 or not power-of-two | ✓ warns above 1024 | ✓ warns above 512 | ✓ warns above 1024 |
| newQuad(x, y, w, h, sw, sh or image) | ✓ | ✓ | ✓ | ✓ | ✓ |
| draw(drawable, x, y, r, sx, sy, ox, oy) | ✓ through a scaled, mirrored copy per sheet; the source is never resized or flipped | ✓ same as OL | ✓ `drawScaleImage` / `drawImageExtended` | ✓ tiny3D textured quad | ✓ `drawScaleImage` / `drawImageExtended` |
| draw(image, quad, ...) | ✓ sub-rect of that copy; a rotation turns the whole copy | ✓ same as OL | ✓ | ✓ quad UVs, mirroring swaps them | ✓ |
| setColor(r, g, b, a), **0 to 1** | ✓ tints whole images (`image.blittint`); quads take alpha only | ✓ same as OL | ✓ tints every draw | ✓ tints every draw (vertex colour) | ✓ tints every draw |
| getColor / setBackgroundColor / getBackgroundColor | ✓ | ✓ | ✓ | ✓ | ✓ |
| clear(...) | ✓ | ✓ | no-op (the frame loop clears) | no-op | no-op |
| setBlendMode / getBlendMode | tracked | ✓ `add` / `subtract` on whole images | tracked | ✓ all eight modes (`gfx.BlendFunction`) | tracked |
| isBlendModeSupported(mode) *(wrapper extension)* | ✓ | ✓ | ✓ | ✓ | ✓ |
| setLineWidth / getLineWidth | ✓ | ✓ | ✓ | ✓ thick lines | ✓ |
| setLineStyle / setLineJoin / setPointSize | stub | stub | stub | stub | stub |
| newFont / setFont / getFont / setNewFont | ✓ TTF, cached per face and size | ✓ PGF system face, size varies | ✓ TTF | ✓ TTF (`gfx.FontAddTTF`), metrics estimated | ✓ TTF |
| print(text, x, y) | ✓ follows the transform stack | ✓ | ✓ | ✓ | ✓ printed after the frame, always on top |
| printf(text, x, y, limit, align) | ✓ wrap, left / center / right | ✓ | ✓ | ✓ | ✓ |
| rectangle / circle / ellipse / arc / line / points | ✓ | ✓ | ✓ | ✓ | ✓ |
| polygon(mode, vertices) | ✓ even-odd scanline fill | ✓ | ✓ | ✓ | ✓ |
| push / pop / origin / reset | ✓ | ✓ | ✓ | ✓ | ✓ |
| translate / scale / rotate | ✓ images, shapes and text; `rotate` does not rotate later positions | ✓ | ✓ | ✓ | ✓ |
| shear | stub | stub | stub | stub | stub |
| applyTransform / replaceTransform | ✓ translation, rotation and scale (shear dropped) | ✓ | ✓ | ✓ | ✓ |
| transformPoint / inverseTransformPoint | ✓ | ✓ | ✓ | ✓ | ✓ |
| setScissor / getScissor / intersectScissor | tracked | tracked | ✓ software reject | tracked | ✓ GPU scissor |
| stencil / setStencilTest / getStencilTest | stub | stub | stub | stub | stub |
| setDefaultFilter / getDefaultFilter | ✓ applied to new images and scaled copies | tracked | ✓ applied to new images | tracked | tracked |
| setTextureInset / getTextureInset *(wrapper extension)* | ✓ | ✓ | ✓ whole texels | none on the draw | ✓ whole texels |
| newCanvas / setCanvas / getCanvas | stub: draws go to the screen, drawing the Canvas does nothing | stub | stub | stub | stub |
| newShader / setShader / getShader | stub | stub | stub | stub | stub |
| newSpriteBatch | ✓ | ✓ | ✓ | ✓ | ✓ |
| newText / newTextBatch | ✓ | ✓ | ✓ | ✓ | ✓ |
| newParticleSystem | basic | basic | basic | basic | basic |
| newMesh | stub | stub | stub | stub | stub |
| getDimensions / getWidth / getHeight | 960x544 | 480x272 | 960x544 | 720x480 | 400x240 |
| getSystemLimits / getSupported | ✓ from the capability table | ✓ | ✓ | ✓ | ✓ |
| getStats / getRendererInfo / isGammaCorrect / isActive / present | ✓ (stats are all zero) | ✓ | ✓ | ✓ | ✓ |
| captureScreenshot | stub | stub | stub | stub | stub |

SpriteBatch, Text and ParticleSystem objects replay their draws inside the
transform of the call that draws them, so `draw(batch, x, y, r, sx, sy, ox, oy)`
places, turns and scales the whole object. ParticleSystem is a basic emitter:
emission rate, lifetime, speed, direction and spread work; size, colour and
rotation curves are accepted and ignored.

### Font object methods

One shared Font implementation (`core/font.lua`); only measuring and loading
are native.

| Method | OL | PSP | LPP | PS3 | 3DS |
|---|---|---|---|---|---|
| getWidth(text) | ✓ `screen.textwidth` | ✓ `screen.textwidth` | ✓ `Font.getTextWidth` | estimate: glyphs × size × 0.6 | ✓ `Font.measureText` |
| getHeight / getBaseline / getAscent | the requested size | same | same | same | same |
| getDescent / getKerning / getDPIScale | 0 / 0 / 1 | same | same | same | same |
| getLineHeight / setLineHeight | ✓ default 1.2, used by printf | same | same | same | same |
| getWrap(text, width) | ✓ | ✓ | ✓ | ✓ | ✓ |
| hasGlyph / setFallbacks / getFilter / setFilter | stub | stub | stub | stub | stub |
| type / typeOf / release | ✓ | ✓ | ✓ | ✓ | ✓ |

printf line spacing is `getHeight() * getLineHeight()` and wrapping is measured
with the font itself. Unlike LÖVE, getHeight is the requested size and the
default line height is 1.2, which together give roughly LÖVE's spacing.

### Image object methods

`newImage` returns one shared Image object (`core/image.lua`) with the SDK's
texture inside; draws unwrap it. lpp-vita and lpp-3ds return textures as
integers, so a bare handle would raise on any method call.

| Method | All backends | Native where |
|---|---|---|
| type / typeOf | `"Image"`; also a Texture, Drawable and Object | |
| getWidth / getHeight / getDimensions | ✓ | |
| getPixelWidth / getPixelHeight / getPixelDimensions / getDPIScale | ✓ (`1`) | |
| getFilter / setFilter | ✓ starts at the default filter | OL: `image.setfilter`; LPP: `Graphics.setImageFilters`; elsewhere tracked |
| getWrap / setWrap | tracked | no SDK samples outside a quad |
| getMipmapFilter / setMipmapFilter | no mipmaps (`nil` / no-op) | |
| getTextureType / getFormat / isCompressed / isReadable / getMipmapCount | `"2d"` / `"rgba8"` / false / true / 1 | |
| replacePixels | no-op | |
| release | ✓ true once | LPP and 3DS free the texture (`Graphics.freeImage`) |

---

## love.timer

| Function | All backends |
|---|---|
| getTime | ✓ (PS3 has no timer: the frame clock, advancing by each frame's dt) |
| getDelta | ✓ the fixed update slice `love.update` was called with |
| getFPS / getAverageDelta | ✓ the measured render rate over the last 30 frames |
| sleep | ✓ (busy-waits where the SDK has no delay call: 3DS, older lpp-vita) |
| step | ✓ the last frame time; the main loop does the measuring |

Updates run on a shared fixed-timestep accumulator (`core/timestep.lua`):
`love.update` is called in `1/lv1luaconf.updaterate` slices (default 60 per
second), the leftover time carries into the next frame, and
`lv1luaconf.maxframeskip` (default 5) caps the catch-up after a stall.
`updaterate = "variable"` restores desktop LÖVE's one update per frame. The PS3
assumes one slice per frame.

---

## love.keyboard

| Function | All backends |
|---|---|
| isDown(key, ...) / isScancodeDown | ✓ true when any of the keys is down |
| hasKeyRepeat / setKeyRepeat | ✓ off by default; repeats after 0.4 s, then every 0.05 s |
| getKeyFromScancode / getScancodeFromKey | identity (no scancodes on a pad) |
| showTextInput / setTextInput | ✓ on OL, PSP and LPP; stub on PS3 and 3DS |
| hasTextInput | `false` |

---

## love.audio

One shared Source (`core/audio.lua`); each backend supplies only native hooks.

| Function | OL / PSP | LPP | PS3 | 3DS |
|---|---|---|---|---|
| newSource(file, type) | ✓ MP3; other extensions are mapped to `.mp3` | ✓ | ✓ `stream` only; a `static` source loads nothing | ✓ WAV, OGG, AIFF |
| play / stop / pause (one source, several, or a list; none means all) | ✓ | ✓ | ✓ | ✓ |
| getVolume / setVolume (master) | ✓ | ✓ | ✓ | tracked |
| getActiveSourceCount / getSourceCount | ✓ | ✓ | ✓ | ✓ |
| isEffectsSupported / listener API | `false` / stub | same | same | same |
| Simultaneous voices | 2 (one static, one stream) | 8 | 1 (the last stream played holds it) | 24 |

### Source object methods

| Method | Notes |
|---|---|
| play | LÖVE 11: does nothing on a playing source, resumes a paused one |
| stop | rewinds; on LPP the track is closed and reopened, because the SDK has no stop |
| pause / resume | ✓ (`resume` is kept although LÖVE 11 dropped it) |
| isPlaying / isPaused / isStopped | ✓ |
| setVolume / getVolume | ✓ 0 to 1, scaled by the master volume; 3DS tracked only |
| setLooping / isLooping | ✓ |
| tell(unit) / seek(position, unit) | timed from `love.timer.getTime`; no SDK here reports or moves a playback position, so `seek` moves only the reported one |
| setPitch / getPitch | tracked and applied to the timed position |
| getDuration | native where exposed, else read from a WAV header, else 0 |
| clone | ✓ copies volume, pitch and looping |
| release | ✓ frees the native track where the SDK can (LPP) and forgets the source |
| type / typeOf / getType | ✓ |

---

## love.filesystem

| Function | Notes |
|---|---|
| read / write / append | ✓ save directory first, then the game directory |
| lines | ✓ strips `\n` and `\r\n`, no empty line after a final newline |
| load | ✓ |
| getInfo(file, filtertype) | ✓ real `size`; `type` tells file from directory; `modtime` is 0 (no SDK exposes a file date) |
| isFile / isDirectory | ✓ |
| remove / createDirectory | ✓ |
| getDirectoryItems | ✓ merges the game and save directories, sorted, no duplicates |
| newFile(name, mode) | ✓ opens straight away when a mode is given; open handles are closed at `love.event.quit` |
| newFileData | ✓ |
| getIdentity / setIdentity | ✓ |
| getSaveDirectory / getUserDirectory / getAppdataDirectory | ✓ |
| getWorkingDirectory / getRealDirectory / getSourceBaseDirectory | ✓ |
| mount / unmount | stub |
| isFused | `true` |

Save locations: Vita `ux0:/data/<identity>/savedata/`, 3DS
`/3ds/data/<identity>/`, PSP `ms0:/PSP/GAME/LOVE-WrapLua/savedata/`, PS3
`<game folder>/savedata/`. On the Vita and 3DS `setIdentity` moves the save
directory; the PSP and PS3 keep one folder beside the game.

---

## love.math

| Function | Notes |
|---|---|
| random / setRandomSeed / getRandomSeed | ✓ own L'Ecuyer generator (not Lua's `math.random`), the same stream on every Lua version; both seed words are used |
| randomNormal | ✓ Box-Muller |
| newRandomGenerator | ✓ `getState` returns both words as `"s1,s2"` |
| noise(x, y, z, w) | ✓ Perlin 1D to 4D, 0 to 1 |
| newTransform | ✓ full 2D affine |
| newBezierCurve | ✓ evaluate / render |
| isConvex / triangulate | ✓ (ear clipping) |
| colorFromBytes / colorToBytes / gammaToLinear / linearToGamma | ✓ |

---

## love.window

Every function exists. The window is always fullscreen at the console's
resolution, so `setMode` and `setFullscreen` change nothing and `getMode`
reports the fixed mode.

---

## love.joystick

One virtual gamepad, filled every frame by the backend.

| Function | Notes |
|---|---|
| getJoysticks / getJoystickCount | one controller |
| Joystick:getAxis / getAxes | ✓ left and right stick (3DS: circle pad only) |
| Joystick:isDown / isGamepadDown | ✓ |
| Joystick:getGamepadAxis | ✓ leftx / lefty / rightx / righty |
| Joystick:getHat | ✓ the d-pad |
| Joystick:getName / getID | ✓ |
| Joystick:isVibrationSupported / setVibration | `false` / stub |

---

## love.data

| Function | Notes |
|---|---|
| encode / decode | ✓ base64 and hex; the `"data"` container returns a ByteData |
| hash | ✓ md5, sha1, sha224, sha256, sha384, sha512 (vendored sha2.lua), raw digest |
| compress / decompress | ✓ deflate and zlib (vendored LibDeflate), byte-compatible with desktop LÖVE; `gzip` and `lz4` fall back to deflate |
| newByteData / newDataView / getSize | ✓ |
| pack / unpack | ✓ on Lua 5.3+ only |

---

## love.touch / love.mouse (OneLua on Vita)

Loaded on the Vita whatever the button layout; no other backend defines them.

| Function | Notes |
|---|---|
| love.touch.getTouches / getPosition(id) / getPressure(id) | ✓ front panel; an id that is not down reads `0, 0` |
| love.mouse.getX / getY / getPosition | ✓ the last position of the first finger |
| love.mouse.isDown(button) | ✓ the first finger is button 1 |
| love.mouse.setPosition / setVisible / setGrabbed / setRelativeMode | stub |

---

## love.system

| Function | Notes |
|---|---|
| getOS | `"LOVE-WrapLua"` |
| getLanguage | ✓ native on OL (`os.language`), LPP and 3DS; `"en"` elsewhere |
| getUsername | ✓ native on OL (`os.nick`), LPP and 3DS; `""` elsewhere |
| getProcessorCount | from the capability table: Vita 4, PSP 1, PS3 2, 3DS 2 |
| getPowerInfo | ✓ native on LPP and 3DS (3DS in 20% steps); `"nobattery"` on PS3; `"unknown"` on OneLua |
| setClipboardText / getClipboardText | process-local |
| openURL / vibrate / hasBackgroundMusic | `false` / no-op / `false` |

---

## love.thread

`newThread(file or source)`, `getChannel`, `newChannel`, `getThread`,
`getThreads`; Channel `push`, `pop`, `peek`, `clear`, `hasRead`, `getCount`,
`supply`, `demand`, `performAtomic`.

**Synchronous by design.** There is no OS threading here: a thread runs as a
coroutine when `start(...)` is called (its arguments forwarded) and finishes
before `start` returns, unless it yields. An error in its body is caught:
`getError` returns it and `love.threaderror` is called. `Channel:supply` is an
immediate push and `Channel:demand` a non-blocking pop that returns `nil` on an
empty channel, so producer/consumer logic must not rely on blocking.

---

## love.event

`quit(restart)` asks `love.quit` first (true cancels), closes every open
`newFile` handle so saves are flushed, then leaves through the SDK's own exit.
`"restart"` relaunches on OneLua and lpp-vita.

---

## Nintendo 3DS notes (lpp-3ds)

Written against the lpp-3ds sources (`source/lua*.cpp`) and sf2dlib, which
`Graphics.*` wraps; `tests/mock_3ds.lua` raises wherever the real binding raises.

| Area | Note |
|---|---|
| Screen | top screen only, 400x240; `Graphics.initBlend(TOP_SCREEN)` each frame |
| Draw | `drawScaleImage` (top-left) unrotated, `drawImageExtended` (centre-placed, texture tenth) otherwise |
| Primitives | `fillRect` / `fillEmptyRect` / `drawLine` take `(x1, x2, y1, y2, color)`; `drawCircle` takes an integer radius |
| Text | `Font.print` writes the CPU framebuffer after the GPU frame, so text is always on top; a line starting off screen (past 400x227) is skipped because the binding raises there |
| Draws outside love.draw | dropped with one warning: the GPU accepts draws only inside the frame |
| Audio | `Sound.openWav` / `openOgg` / `openAiff`; no MP3, no stop (a pause), no volume, pitch or seek |
| Files | lpp-3ds replaces `io.open/read/write/close`, so every file goes through `3DS/fileio.lua` |
| Input | A/B/X/Y take the PlayStation positions (A is the confirm slot under the default layout); the circle pad is the left stick |
| Quit | flushes files, `Sound.term`, `Graphics.term`, then `System.exit` |

---

## Emulator and renderer caveats

Emulators are a development convenience, not a validation target. Each backend
records its usual emulator and the areas it gets wrong in
`love._backend.emulator` and `love._backend.rendersensitive`
(`blendmode`, `framebufferread`, `texturefilter`, `savepersistence`).

| Backend | Emulator | Renderer-sensitive |
|---|---|---|
| OL, LPP | Vita3K | blendmode, framebufferread, savepersistence |
| PSP | PPSSPP | texturefilter, framebufferread |
| PS3 | RPCS3 (homebrew loading unreliable) | all four |
| 3DS | Citra / Azahar | blendmode, framebufferread, savepersistence |

- **Vita3K:** programmable blend and framebuffer reads are inaccurate and vary
  between OpenGL, Vulkan and MoltenVK (Vita3K #4109, #422); writes can be lost
  when the emulator closes (#3918, #3659).
- **PPSSPP:** linear filtering bleeds a row of texels from the far edge of a
  quad (#14977); framebuffer and texture sizing can differ from hardware (#3085).
  Use `love.graphics.setTextureInset(0.5)` or nearest filtering.
- **RPCS3:** homebrew loading is minimal (#18997), so the PS3 backend cannot be
  validated there.

---

## Known limitations

- **Canvas** is unsupported (`getSupported().canvas` is false): `renderTo`
  draws to the screen and drawing the Canvas does nothing. Native paths exist:
  vita2d has rendertarget textures with no Lua binding in lpp-vita (a small
  upstream patch), tiny3D has scene-to-texture surfaces; OneLua exposes none.
- **Shader and Mesh** are stubs: no SDK exposes a programmable pipeline or
  arbitrary vertex submission to Lua.
- **Rotation** in the transform stack turns what is drawn but not the positions
  that follow it: the stack keeps an offset, a scale and an angle per level.
  `shear` is a stub.
- **OneLua** (Vita and PSP) draws a scaled or mirrored image from a copy built
  once per sheet and scale; a rotated quad turns that whole copy, and a quad's
  tint is alpha only.
- **Texture limits:** `newImage` / `newQuad` warn (once per problem, through
  `lv1lua.warn` if set) when a sheet is over the backend's `texturesize` or, on
  the PSP, not a power of two. Split or pad the sheet.
- **Quad edge-bleed:** `love.graphics.setTextureInset(px)` (a wrapper extension,
  default 0) shrinks each quad's source rect by `px` texels per side. lpp-vita
  and lpp-3ds read the source origin as an integer, so there it rounds inward to
  whole texels.
- **Audio:** OneLua plays two voices at once, the PS3 one stream; positions and
  pitch are timed in software.
- **love.data:** hashing and compression are pure Lua and slow on device; cache
  the results.
- **Colour** is 0 to 1, as in LÖVE 11: code written for 0 to 255 must change.
