## Changelog

## 0.8.0 (2026-10-05)

First release of this continuation of LOVE-WrapLua. It covers every entry
below down to the original project's history.

### 2026-10-05, branch `fix/r2-review` (second whole-repository review)

A full read of the code plus a QA pass against the mocks (see
`CODE_REVIEW.md`). Every defect below was reproduced first and has a test.

**Fixes, every backend**
- Nested `push` levels composed in the wrong order: `scale(2) push()
  translate(-10)`, the usual pixel-art camera, mapped x to 2x - 10 instead of
  2(x - 10). `applyTransform` also dropped a Transform's rotation.
- Drawing a Canvas crashed on OneLua Vita and the 3DS and handed a Lua table to
  the native blit elsewhere; it is now a no-op (its content is already on
  screen).
- `draw(batch, x, y, r, sx, sy, ox, oy)` on a SpriteBatch, Text or
  ParticleSystem used only x and y; the whole call now places the object.
  `SpriteBatch:set` from a quad to a position kept the quad; `Text:addf` left
  the size at zero.
- `arc("line", "open", ...)` drew its closing chord. `imgscale` / `resscale`
  reached rectangles only, and raised on the 3DS, which has no scale factor.
- `love.keyboard.isDown(k1, k2, ...)` checked the first key only. The gamepad
  bridge sent the d-pad as `up` instead of `dpup`, and key repeats as presses.
  An unknown `keyconf` left the button map nil.
- `love.quit` returning true did not cancel the quit.
- `love.filesystem.newFile(name, mode)` never opened the file, so writes were
  lost; `lines()` yielded an empty last line after a final newline and kept
  `\r`; `setIdentity` did not move the save directory.
- A thread that raised took the game down; errors now reach `getError` and
  `love.threaderror`, and `newThread` accepts Lua source.
- `love.audio`: play restarted a playing source (LÖVE 11 does nothing) and did
  not resume a paused one; `release` kept every source alive in the registry;
  `play` / `stop` / `pause` took only one source.
- `love.data.encode`, `decode` and `hash` returned a second value.
- A `conf.lua` without `love.conf` crashed the boot.

**Fixes, per backend**
- OneLua (Vita and PSP) share one image draw (`OneLua/imagedraw.lua`). On the
  Vita each Quad held its own scaled copy of the whole sheet, a mirrored draw
  flipped the shared source so a cached copy came back mirrored, and a mirrored
  quad was offset by the sheet's width.
- `print` ignored the transform stack on the PSP and lpp-vita and dropped the
  translation on OneLua Vita.
- ParticleSystem and Mesh existed on OneLua Vita only.
- Vita touch raised `mousepressed` and nothing else; every touch and mouse
  callback now fires. The OneLua `require` reported an error inside a game
  module as the module being missing.
- PS3: quads were drawn at the whole sheet's size and mirroring was ignored; a
  second stream source stole the voice at load and replay after `stop` was
  silent; `love.timer.getTime` counted whole seconds.
- lpp-vita, grounded in `luaSound.cpp`: a fractional volume raised
  (`luaL_checkinteger`), `play` reset the volume, `resume` started a duplicate
  track, and stop leaked a paused audio thread. Fractional font pixel sizes,
  which also raise there, are rounded.

**Cleanup**
- Removed dead code (`OneLua/font.lua`, the unreachable Live Area WIP, the
  `loadsound` alias) and comments that narrated history or cited task IDs.
- README, Implemented.md, AGENTS.md and the vendor notes rewritten against the
  current code.

### 2026-10-05, branch `feat/t7.7-psp-transforms`

**Features**
- The PSP runs on the real transform stack. `push`, `pop`, `translate`,
  `scale`, `rotate`, `applyTransform` and `transformPoint` were identity stubs
  there, so a game that places its scene through the stack (a camera, UI
  scaling) drew wrong on the highest-priority target only. Images, quads and
  primitives now all follow it.

**Fixes**
- OneLua Vita folded the stack into image draws two different wrong ways: with
  `scale(2)` and `translate(10, 0)` active, `draw(img, 5, 0)` landed at x=45
  and the same draw through a full-sheet quad at x=25, while a rectangle in
  the same frame (and LOVE) land on 30. Both paths now map the anchor as
  `p*S+O`, like primitives and every other backend.
- `intersectScissor` replaced the active scissor instead of shrinking it to
  the overlap, so a clipped panel inside a clipped window could draw outside
  its parent. It now intersects (disjoint rectangles give an empty scissor),
  on every backend through the shared transform surface.

**Refactor**
- The love.graphics transform and scissor surface is one shared file,
  `core/transformapi.lua`, instead of four near-identical backend copies. The
  3DS hardware scissor is the optional `lv1lua.gfx.applyScissor` hook.
- Tests: `tests/draw_transform_test.lua` checks that an image, a quad and a
  rectangle agree under the stack on PSP and OneLua Vita.

### 2026-10-03, branch `feat/t7.6-image-objects`

**Fixes**
- `newImage` returns a real Image object on every backend (`core/image.lua`).
  lpp-vita, the 3DS and the PSP handed the game the bare SDK handle (an integer
  on lpp-vita and lpp-3ds), so any Image method, including the
  `image:getWidth()` that anim8 and desAnim8 call, crashed on device; the PS3
  object had only the three size getters. The object carries the full LOVE
  Image/Texture surface: `type`/`typeOf`, size and pixel-size getters,
  `getFilter`/`setFilter` (native on lpp-vita through
  `Graphics.setImageFilters`), `getWrap`/`setWrap`, the texture queries and
  `release` (frees the texture on lpp-vita and the 3DS). Draws unwrap it with
  `lv1lua.core.texture`, so the SDK still receives its own handle.
- Tests: the lpp-vita mock now returns integer texture handles, as the console
  does, and `tests/image_test.lua` checks the Image surface and the native
  handle on all five backends.

### 2026-10-03, branch `fix/t7.5-native-grounding`

Native contracts re-checked against upstream source (lpp-vita, libvita2d,
lpp-3ds, sf2dlib).

**Fixes**
- lpp-vita: `Graphics.drawImageExtended` places the scaled sub-rect by its
  **centre** and rotates around it (libvita2d
  `draw_texture_part_scale_rotate_generic`), but the backend passed the
  top-left corner. Every quad draw (all spritesheet animation) and every rotated
  draw landed half its size up and to the left, and rotated around the wrong
  point. The centre is now derived from LOVE's pivot and origin
  (`lv1lua.util.spriteCentre`).
- lpp-vita: mirrored draws (`sx = -1` with `ox = w`, the usual flip idiom)
  applied the origin with `abs(scale)`, so the image landed a full width to the
  left; the scissor reject also rejected mirrored draws that were on screen.
  The origin and the scissor box now use the signed scale.
- lpp-vita: `drawImageExtended` reads `st_x` / `st_y` with
  `luaL_checkinteger`, which raises on Lua 5.3 for a fractional value, so
  `setTextureInset(0.5)` crashed the first quad draw. The inset now rounds
  inward to whole texels there (`lv1lua.core.insetQuadTexels`).
- Tests: `__checkInteger` in `mock_common.lua` encodes the Lua 5.3 integer rule;
  the lpp-vita mock applies it to the source origin.
- lpp-vita and 3DS: `Graphics.loadImage` returns the texture as an integer, so
  `newQuad(x, y, w, h, image)` took the handle for the sheet width. The image
  form is now told apart from `(sw, sh)` by the argument count, and the 3DS mock
  hands out integer handles like the console.
- 3DS: the T6.4 backend was written against a mock nobody had checked against
  lpp-3ds, and almost every native call differed. Rewritten against the player's
  own bindings:
  - `Graphics.*` draws only between `initBlend(TOP_SCREEN)` and `termBlend()`
    (`TOP_SCREEN` is `0`, not `1`), so the frame now opens and closes the GPU
    pass; draws outside `love.draw` are dropped with a warning instead of
    raising.
  - Primitives use lpp-vita's `(x1, x2, y1, y2, color)` order with no screen
    argument; `drawRect` / `fillCircle` do not exist (`fillEmptyRect` /
    `drawCircle`, integer radius).
  - `drawImageExtended` takes the texture tenth and the sprite centre, and it
    tints, so `setColor` now reaches every 3DS draw.
  - `Font.print` is `(font, x, y, text, color, screen)` into the CPU framebuffer:
    text is queued during the frame and printed after `termBlend` (otherwise the
    GPU transfer paints over it), positions are rounded to integers, and lines
    starting off screen are skipped instead of raising. Measuring uses
    `Font.measureText` (there is no `getTextWidth`).
  - `Sound` has no `open`, `stop`, volume or seek: sources open with
    `openWav` / `openOgg` / `openAiff` by extension, stop is a pause, and
    `play(handle, loop)` passes the looping flag.
  - Input reads `Controls.readCirclePad` (there is no `getCircleX`) with up as
    negative Y, and the face buttons take the PlayStation positions so
    `love.joystick` sees them (they were named `a`/`b`/`x`/`y`, which the
    gamepad map never matched).
  - `Timer.delay` does not exist; `sleep` spins on the timer.
  - Scissor is real on the GPU through `Graphics.setViewport`.
- 3DS file access: lpp-3ds rebinds `io.open/read/write/close` to handle-based
  `System.openFile` calls, so every `io.open` in the shared modules raised there.
  A small seam, `core/fileio.lua` (`open`, `loadfile`), now carries all file
  access; on every other backend it is the standard library, and
  `3DS/fileio.lua` implements it over `System.openFile` (truncating on `"w"`,
  which `FCREATE` alone does not, and finding directories by listing the
  parent). `require` and `love.filesystem.load` compile through it too.
- 3DS boot: lpp-3ds also boots `index.lua`, which hard-coded lpp-vita. It now
  detects the player by `TOP_SCREEN`, and takes `dataloc` from `romfs:/` (CIA)
  or `System.currentDirectory()` (.3dsx). Saves go to `/3ds/data/<identity>/`.
- `love.system` on the 3DS: battery level (PTMU 0-5) as a percentage, the CFG
  language index as a language code, native username.
- Capability table: the 3DS decodes WAV / OGG / AIFF (not MP3) on 24 NDSP
  channels.
- Tests: `tests/mock_platform.lua` inherited `__MODE` from whichever suite ran
  before it in `run_all`, so the "OneLua" suites could silently run under
  another backend; it is now always OneLua. The 3DS joined the globals,
  timestep, input, audio, system, capabilities, objects, filesystem and
  bootstrap suites.
- Docs: README, `Implemented.md` and `AGENTS.md` describe the 3DS backend, and
  the PS3 rows now match T6.6 (tier 2, real tiny3D draws and primitives).

### 2026-09-16, branch `fix/phase0-1-correctness`

Backend-independent sprite drawing and the desAnim8 rework.

**Fixes / features**
- lpp-vita `draw` now handles the quad form and rotation through the native
  `Graphics.drawImageExtended`, keeping `drawScaleImage` as the unrotated fast
  path (T2.1). SpriteBatch/Text objects that draw themselves are dispatched too.
- lpp-vita joined the shared software transform stack: translate/scale/rotate/
  push/pop/origin, applyTransform/replaceTransform and transformPoint compose
  into every draw; `setScissor` is enforced by rejecting draws whose box falls
  outside the region (T2.2).
- PSP `draw` gained a real quad sub-rect blit (source stays immutable; scale and
  flip reuse the cached copy). PS3 `draw` accepts a quad so quad-based libraries
  run, but ignores it and draws the whole surface (least-supported tier).
- `desAnim8` rewritten (T9.1): a modular, backend-independent library (Grid +
  Animation) that draws only through `love.graphics.draw(image, quad, …)`, with
  no reach into native image data. Adds per-frame durations, flipH/flipV, clone,
  pause/resume/gotoFrame, play-once with a one-shot completion callback, and a
  current-frame query. The old `desAnim8.new` single-strip constructor still
  works via a shim. Upstream `anim8` now runs on all four backends too.
- `polygon('fill', …)` actually fills (T4.2). A shared even-odd scanline
  rasteriser (`core/polyfill.lua`) replaces the convex-only centroid fan, so
  concave shapes fill correctly on OneLua, PSP and lpp-vita; each backend just
  supplies a one-row `fillSpan`. `ellipse`/`arc` fills ride the same path.
- Honest capabilities (T4.5): a central `core/capabilities.lua` records each
  backend's real caps, and `getSupported`/`getSystemLimits` now come from it on
  all four backends (lpp-vita and PS3 previously exposed neither). Reports
  `canvas=false`/`glsl3=false` everywhere, the true texture limit per backend
  (512 on OneLua/PSP/PS3, 1024 on lpp-vita), and a wrapper-internal
  `love._backend.features` table (transform/quaddraw/scissor/…) for the docs.
- Canvas documented honestly per backend (T4.3): `Implemented.md` and `README.md`
  now state that offscreen rendering is unsupported everywhere today
  (`canvas=false`), and record the concrete native path for each backend:
  lpp-vita/vita2d rendertarget bind (small upstream patch), PS3 tiny3D
  scene-to-texture surfaces (T6.6), OneLua none. Also refreshed stale README/
  Implemented notes (polygon fill, transforms, lpp-vita quad/line bugs) that the
  T2.1/T2.2/T4.2 work already resolved.

**Tests**
- `test_primitives` gained lpp-vita cases for the quad/rotation draw and the
  transform-stack + scissor behaviour.
- New `test_desanim8`: the library runs under all four backend mocks:
  integer-dt frame advance, independent `clone():flipH()`, one-shot play-once
  callback, and the source image is never resized.

---

### 2026-09-15, branch `fix/phase0-1-correctness`

Correctness work from `CODE_REVIEW.md` / `FIX_PLAN.md`, plus a modular
restructure. Every behavioural change landed with a test that fails before it
and passes after; the suite runs on lua5.1, lua5.4 and luajit.

**Fixes**
- Default font is a real Font object on all four backends, so `print` before
  any `setFont` no longer dies on nil arithmetic (#9).
- Real text metrics (#10): lpp-vita uses the native `Font.getTextWidth` (the
  "not exposed" comment was wrong), OneLua and PSP measure whole UTF-8 glyphs
  instead of bytes, and `printf` wraps and aligns on measured width. PS3 still
  estimates, but per glyph.
- `RandomGenerator` replaced with L'Ecuyer's combined generator (#11): the old
  LCG lost its low bits past 2^53 from the second draw on and ignored `seed2`.
  Output is now identical on lua5.1, lua5.4 and luajit.
- PSP `draw` no longer mutates the source image (#6, previously fixed only on
  the Vita path), and a negative scale mirrors properly instead of resizing to
  a negative width.
- `keypressed` / `keyreleased` are edge-triggered on every backend, with
  `isrepeat` and a working `setKeyRepeat`; OneLua used to fire every frame a
  button was held. The `dt` global leak in all three frame loops is gone.
- `love.math.noise` handles the 4th dimension, and loading it no longer
  reseeds Lua's global RNG.

**Structure**
- Each `love.*` module is now an entry point that loads one file per area:
  `OneLua/graphics/`, `OneLua/psp/`, `lpp-vita/graphics/`, `PS3/graphics/`,
  `math/`. The 1117-line OneLua graphics file and the 328-line PSP fork are
  gone.
- New `LOVE-WrapLua/core/`: `loader`, `util`, `transform`, `textwrap`, `input`,
  `runtime`, `config`, `modules`, `require`, `callbacks`. Backends share state
  through `lv1lua.gfx`, never through file-locals.
- `printf` on lpp-vita, PSP and PS3 now shares one wrap implementation, which
  also gained newline handling and correct treatment of a word wider than the
  wrap box.

**Tests**
- PSP went from no coverage to a tested backend (`__MODE = "PSP"`).
- New suites: `test_core` (util, transform stack, word wrap), `test_bootstrap`
  (loader, runtime, config), `test_text` (metrics across four backends),
  `test_input` (key edges and repeat, core plus all three loops).
- Mocks gained a drivable pad (lpp-vita, PS3), a touch panel (OneLua), and
  glyph-based text measuring, so a wrapper that measures bytes fails the suite.

**Known gaps after this work**
- PS3 draws whole surfaces only: no quad sub-rect, scale or rotation (Lua Player
  limit). Quad-based libraries run but render the full sheet there.
- PSP quad draw rotates the whole cached copy, so rotating a single frame of a
  packed sheet is imprecise; document per-frame sheets for rotated sprites.
- The GitHub CI runs are red for a billing lock on the account, not for a code
  failure.

---

- By Hipreme/MrcSnm:
### OneLua/PS_Vita Only
- Support most of love.graphics functions 
- touch.lua and mouse.lua added 
- Added command for resetting (Hold LEFT, UP, SQUARE, TRIANGLE, L and press R)
- Support for quads, global scale and offset
- Added printf function for right, left and center alignment
- Backwards WrapLua compatibility
- Now it supports love2d objects (Now you can call imageInstance:getWidth() etc)
- Added some do-nothing functions for not breaking code compatibility with desktop version
- Correctly replaced 'require' function
- Added callbacks onResume and onLiveArea

### Needing
- Rotated text
- Blend modes
- Shader support
- Tint blit for everything
- Better image.blit for quads


#### Known Issues
- Calling screen.textwidth(font, text, size) will make the font passed on the argument to blur, the current workaround is creating a clone e.g loading the same font 2 times and then using the guinea pig to get the text width
- Calling image.blit() for a resized image quad will mantain the texture size, the current workaround is loading a image copy with image.copyscale() for the size needed, it will cache this resized image until it's scale is changed, the problem is that it will lag a bit when caching, don't know to what extent this is possible, and doing scale animations with images from quad is really inusable
- The only supported audio that didn't crash the engine was mp3 at a 44100 sample rate, wav file didn't crash, but sounded strange, need more tests



#### OneLua Wrong Documentations
- screen.textheight -> Actually receiving (string) instead receiving (userdata, number), actually returning 20 no matter what, the Y offset = 18.5
- image.setfilter -> Actually receives a image and the 2 types (image, number, number), image, mag, min

##### EXTRA
- Tool for sending every type of file for Linux, called fastCurl, just call
```sh
./fastCurl.sh "filetype"
```
- Type only the filetype, without the ".", it will send recursively every "filetype" from the folder inside ./homebrew, it will send defaultly to ftp://192.168.15.19:1337/ux0:/ONELUAHP0/, change it to your needings, if you cancel while sending the files, enter in the directory of fastCurl and delete the cache .txt files
- Added a tool to convert your audio files recursively instantly, it just requires 'sox' command from shelll, you can find it here: http://sox.sourceforge.net/
- The usage is the same as fastCurl, it won't delete your original audio files, it will create a copy to the supported filetype to vita, the usage is the same and the filetype can be overridden to the "filetype" you specify, the default type is mp3
- A tool for deleting your audios, it is defaulted to only remove mp3 files, there is no confirm button, so take care 
