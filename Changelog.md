## Changelog

## Unreleased

### 2026-11-17, branch `fix/native-psp-particle-fallback`

- Native PSP backend: `noaudio.flag` next to the EBOOT makes every source silent (A/B runs). Measured with it: real
  audio costs Balatro about 12.7 ms per frame (11.9 fps with the mixer, 16.4 fps without); see
  `docs/NATIVE_PSP_AUDIT.md` for the levers. `love_psp.lua` keeps an inert `newParticleSystem` as the fallback for a
  host that does not load `extras.lua`.

### 2026-11-17, branch `feat/native-psp-api-gaps`

- Native PSP backend, API gaps closed (104 `love.*` functions were missing against the LÖVE 11 definitions; about 40
  fewer now, all of `love.physics` and Mesh/Shader/Video still open): `love.graphics.points` (was a no-op), `arc`,
  `newSpriteBatch`, a real `newParticleSystem` (it was an inert stub), `intersectScissor`, `getStackDepth` (new C
  `stack_depth`), `getStats`, the line style / join / point size / wireframe / colour mask / depth mode getters,
  `love.filesystem.newFile` with the whole File object, the path getters, `love.event.wait`, `love.math.getRandomState`
  / `setRandomState` (seed based), and harmless answers for the window, mouse, touch, audio-effect and system probes.
  The code is `PSPNative/extras.lua`; `tests/games/extras` draws it on the EBOOT.
- Shared: `core/objects.lua` split into `core/drawobject.lua` and `core/spritebatch.lua`, so the native backend can use
  the SpriteBatch without the stub Canvas and Shader. A SpriteBatch now applies the colour `setColor` had when each
  sprite was added (it stored the colour and never used it), multiplied with the current colour.

### 2026-11-17, branch `feat/native-psp-audio`

- Native PSP backend: real audio. `native/src/audio.c` mixes up to 24 voices on a thread feeding one sceAudio
  channel (44.1 kHz stereo, 1024 frame blocks). Sources are `.wav` (PCM 8 or 16 bit) or `.ogg` through Tremor
  (`libvorbisidec`), decoded whole when under 3 MB and streamed from the file otherwise or on request, with pitch by
  linear resampling, volume, looping, pause, seek and clone. `love.audio` and `Source` in `love_psp.lua` follow the
  LÖVE 11 API (play, pause, stop, resume, seek and tell in seconds or samples, getDuration, clone, master volume);
  a file that cannot be played gives a silent source and a log line, as the stub did. The test mock has the same
  voice state machine, ten new contract cases cover it, and `tests/games/audio` checks 21 behaviours on the EBOOT in
  PPSSPP (all pass). Not covered: MP3, queueable sources, effects and 3D positions, hearing it on hardware.

### 2026-11-17, branch `docs/native-perf-profile`

- `docs/NATIVE_PSP_AUDIT.md`: sampling profile of the native path in `SELECTING_HAND` (the backend layer is about 5% of
  the frame, the rest is Balatro's Lua on the VM) and the `-O3` A/B (no gain). The Balatro harness now builds its
  EBOOT and backend from this repository through `tools/lovepsp.lua`.

### 2026-11-17, branch `feat/native-psp-shared-modules`

- Native PSP backend: `PSPNative/shared.lua` loads the wrapper's shared `love.math` and `love.data` over the backend
  (noise, triangulate, bezier, Transform, RandomGenerator, colour helpers, pack, unpack, ByteData), keeping the C
  engine's fast paths for `random` / `setRandomSeed`, base64, hex and zlib. `love.data.hash` raises a clear error on
  single precision numbers (`sha2.lua` needs 53 bits); a native hash is open work. Heap after boot is 282 KB.
- `tools/lovepsp.lua` stages the shared modules next to the EBOOT (`stage` command, used by `package` and by the
  tests). `tests/games/shared` checks the lot on the EBOOT in PPSSPP.

### 2026-11-17, branch `fix/random-single-precision`

- `love.math` generators on single precision Lua numbers (the native PSP build keeps 24 exact bits, so the
  L'Ecuyer products no longer fit): a Wichmann-Hill generator with every product below 2^24 takes over, chosen by
  testing the precision at load. Same API, `getState` carries a third word there. Doubles keep the old generator and
  the same sequences. `tests/math_test.lua` forces the console path and checks range, determinism, uniformity and
  cycle length.

### 2026-11-17, branch `fix/love-data-pack`

- `love.data.pack` and `unpack` follow LÖVE's signatures (`pack(container, format, ...)`, `unpack(format, data [, pos])`
  returning the next position) and work on Lua 5.1 and LuaJIT, where the shared module returned an empty string and
  nil. `LOVE-WrapLua/data/pack.lua` implements the Lua 5.3 format language (endianness, `b h i[n] l j T f d n s z c x`)
  with no bit operators and is compared byte for byte against `string.pack` on 5.4 in `tests/data_test.lua`.

### 2026-11-17, branch `feat/native-psp-transform`

- Native PSP backend: the matrix stack stays in C. Measured on the packaged EBOOT in PPSSPP, one synthetic frame
  takes 5.80 ms with the stack in C and 10.00 ms with a Lua stack (`tests/games/stackbench`); the Lua stack also
  cannot rotate later positions. `docs/NATIVE_PSP_AUDIT.md` section 4 has the table.
- C engine: `native.shear`, `get_matrix`, `set_matrix` and `mul_matrix`. `LOVE-WrapLua/PSPNative/love_psp.lua`
  gets `love.graphics.shear` (was a stub), `transformPoint`, `inverseTransformPoint`, `applyTransform` and
  `replaceTransform`. The test mock keeps a real matrix, six new cases check the geometry, and
  `tests/games/matrix` checks it on the EBOOT in PPSSPP (4 of 4 ok).

### 2026-11-17, branch `feat/native-psp-import`

- The native PSP engine and its Lua backend came into this repository: `native/` (C engine, Makefile, Lua 5.1.5
  tarball and a 521-line patch for the single-precision VM) and `LOVE-WrapLua/PSPNative/` (`love_psp.lua`,
  `boot.lua`, `psp_ffi.lua`). Project goal recorded in `AGENTS.md`: write PSP games with LÖVE, Balatro running
  smoothly, performance part of the objective.
- `tools/lovepsp.lua`: build the EBOOT (`build [--double] [--opt=...]`), package a game (`package`) and print the
  directory manifest (`manifest`), in Lua over the shell. A clean `build` takes 15 s; the sample `game/` packaged
  with it renders its animated sprite in PPSSPP.
- `tests/native_psp_test.lua` runs the backend's 68 contract cases (mocked `native`, `tests/native_psp/`) in a
  scratch directory; it runs on Lua 5.1 and LuaJIT and is skipped on 5.3 and 5.4, which lack `unpack` and
  `loadstring` the backend uses.

### 2026-11-17, branch `docs/native-psp-audit`

- `docs/NATIVE_PSP_AUDIT.md`: audit of the native PSP engine in `balatro_psp` as a candidate backend. Balatro
  `SELECTING_HAND` runs at 16.4 fps there (update 31.4 ms, draw 29.7 ms) against 1.1 fps through OneLua; gap list
  against the wrapper, the transform-stack and Lua-crossing decisions, and a suggested order.

### 2026-11-17, branch `perf/transform-deep-stack`

- `docs/PERFORMANCE_FINDINGS.md`: second `love.draw` profile of Balatro's `SELECTING_HAND` (544 samples) and the
  transform stack depth it runs at (4 or 5). Two flatten optimisations were measured and dropped.
- `tests/bench/deep_stack.lua`: VM cost of a nested push/translate/scale/rectangle tree at a given depth.

### 2026-11-17, branch `perf/polygon-fill-hits`

- OneLua (Vita and PSP), lpp-vita and the 3DS gained the `fillRuns` hook the PS3 already had: a cached polygon's
  rectangles are drawn by one backend call that loops over the native fill, instead of one wrapper closure call
  per rectangle. A cache hit on a five-point polygon costs 446 VM instructions, down from 520, and the synthetic
  frame about 4% fewer (lua5.1: PSP 104.7k to 100.7k). `tests/bench/vm_profile.lua` gained the `polygon` and
  `translate` ops.
- Tried and dropped: caching each stack level's composed transform so a change to the top level flattens one
  level. At the depth of the synthetic frame it costs more (`push` + `pop` 93 to 102 instructions): the extra
  stores outweigh the saved loop.

### 2026-11-17, branch `chore/luals-types`

- `.luarc.json` and `types/lv1lua.lua`: LuaLS configuration (Lua 5.5, the love2d library as reference) and the
  `---@meta` types for the names only this wrapper has (`lv1lua`, `lv1luaconf`, `lv1lua.core`, `lv1lua.gfx`). The
  SDK globals each player provides are declared as globals and `duplicate-set-field` is off, since a backend
  redefines the shared function by design. The check from `AGENTS.md` went from 865 to 176 findings; the rest
  (injected fields on `love` tables, signature mismatches against the LÖVE library) are not yet worked through.

### 2026-11-17, branch `feat/screenshot-vita`

- lpp-vita: `love.graphics.captureScreenshot("name.png")` writes the frame to the save directory with
  `System.takeScreenshot` right after the frame that follows the request is presented (PNG, JPEG or BMP by
  extension, PNG when there is none). A callback cannot be served (no ImageData) and warns once.

### 2026-11-17, branch `feat/vibration`

- lpp-vita: `Joystick:setVibration(left, right, duration)` drives `Controls.rumble` with the larger intensity
  (0..255), `getVibration` reads it back, a duration stops it after that much frame time, and
  `isVibrationSupported` is true. The player's `lua_rumble` stores its third argument into the small actuator,
  so both arguments carry the strength. Other backends keep answering `false`; `getVibration` answers 0, 0.

### 2026-11-17, branch `feat/3ds-text-input`

- 3DS: `love.keyboard.showTextInput` / `setTextInput` open lpp-3ds's bottom-screen `Keyboard`. It is shown on
  every `updatecontrols` while open; Enter delivers the whole string to `love.textinput` and closes it, cancel
  closes it with no text, `setTextInput(false)` closes it, and `hasTextInput` reports it. `tbl.text` is the
  starting string. `tests/mock_3ds.lua` gained `Keyboard`, grounded in `source/luaKeyboard.cpp`. Not
  verified on hardware or an emulator: the keyboard draws straight into the bottom screen framebuffer.

### 2026-11-17, branch `feat/scissor-software`

- Vita OneLua and PS3: an image or quad draw that lies wholly outside the scissor is skipped, as on lpp-vita
  (`util.drawBox` gives the sprite's box, turned sprites included). A draw straddling the edge is not cut, and
  primitives and text are not rejected. Synthetic frame: about +1% VM instructions on OneLua.

### 2026-11-17, branch `docs/update-profile`

- `docs/PERFORMANCE_FINDINGS.md`: sampling profile of Balatro's `love.update` in `SELECTING_HAND`. The cost is the
  game's own Moveable, Node, Controller and Card updates; no wrapper function is among the top entries.

### 2026-11-17, branch `feat/bench-wall-time`

- `tests/bench/frame_cost.lua` prints the wall time of one synthetic frame (mean of 200) and the Lua runtime
  (`LuaJIT ... -joff` when the JIT is off, so `luajit -joff` gives the interpreter number). Printed only: never
  part of `--check`, since wall time is not stable across machines.

### 2026-11-17, branch `fix/api-coverage-boot`

- `tests/bench/api_coverage.lua` boots the runtime in the order `script.lua` does. It loaded some modules from
  paths that do not exist (`core/thread.lua`, a `PSP/` backend folder), so `love.thread` and the PSP
  `whileloop`, timer, audio and event modules showed as missing. It prints its usage line when no file is given.

### 2026-11-17, branch `feat/lowmemory`

- `lv1luaconf.lowmemory` (Lua heap in KB) turns on a memory guard checked once per frame in `core.step`:
  `love.lowmemory` is called when the heap passes the limit and again after it has dropped below 90% of it.
  The default handler collects garbage. Off unless configured: `collectgarbage("count")` does not measure
  the console's free memory, so no default limit is safe on every device.

### 2026-11-17, branch `feat/particle-curves`

- `ParticleSystem:setSizes`, `getSizes`, `setColors`, `setSizeVariation`, `getSizeVariation`, `setRotation`
  and `setSpin` take effect: a particle is drawn about the centre of its image with its size, colour and angle
  for its point in life. A system with none of them set draws as before (same call, no extra work per particle).

### 2026-11-17, branch `feat/shear`

- `love.graphics.shear` works. Each stack level keeps a 2x2 matrix, `translate`, `scale` and `shear` compose
  in the level's local space as in LÖVE, and `transformPoint`, `inverseTransformPoint` and `applyTransform`
  (a Transform's shear along x) follow it. Lines, points, polygons, circles, ellipses, arcs and rectangles
  slant exactly; images and text cannot, and only move to the sheared position of their origin. The polygon
  cache key carries the shear. Synthetic frame without shear: +4.9% VM instructions on lua5.1 (one more
  comparison per mapped point, one `mapShear` read per polygon fill).

### 2026-11-17, branch `feat/font-fallbacks`

- `Font:setFallbacks` checks that every argument is a Font and keeps the list. No glyph is drawn from a
  fallback: the SDK print calls take one face per string.

### 2026-11-17, branch `feat/filesystem-mount`

- `love.filesystem.mount` and `unmount` work for directories: the folder is mounted at a mount point, and
  `read`, `load`, `isFile`, `isDirectory`, `getInfo`, `getDirectoryItems` and `getRealDirectory` see it.
  Later mounts win over earlier ones, `appendToPath` puts a mount after the game folder, and the mount point
  shows in its parent's listing. A zip archive returns `false`, as before: no SDK here reads one.

### 2026-11-17, branch `feat/tracked-line-style-font-filter`

- `love.graphics.setLineStyle`, `setLineJoin` and `setPointSize` store the value and the getters read it back
  (they answered the defaults whatever was set). An unknown style or join raises, as in LÖVE. Nothing reaches
  the hardware.
- `Font:setFilter` is kept per font and `Font:getFilter` reads it, falling back to the default filter.
  `Font:hasGlyph` takes strings and code points, answers false for code point 0 and raises on other types.

### 2026-11-17, branch `docs/selecting-hand-measure`

- `docs/PERFORMANCE_FINDINGS.md`: first same-scene number for Balatro (`SELECTING_HAND`): about 1.1 fps through
  the wrapper, against 15.6 fps for the native engine.

### 2026-11-17, branch `perf/polygon-cache-snap`

- `polygon("fill")` (and every shape built on it: rounded rectangles, circles, ellipses) places the cached
  runs at the nearest whole pixel of the shape's origin instead of keeping the sub-pixel part in the cache
  key. An animated polygon used to be rasterised again on every frame; in Balatro's blind-select scene all 40
  fills per draw missed, 61 to 67% of the draw's VM time went into `polygonRuns`, and `love.draw` took
  1090 ms. With the change every lookup hits and `love.draw` takes about 270 ms (emulated PSP clock). A shape
  drawn at a fractional position can sit up to half a pixel from where it sat before; the vertices' own
  fractions are untouched. The cache key's scale is now `mapScale(1, 1)`, no longer the difference of two
  mapped points, which carried float noise from the offset.

### 2026-11-17, branch `fix/coloured-text`

- Coloured text (`{color, "string", color, "string"}`) works in `love.graphics.print`, `printf`,
  `Font:getWidth`, `Font:getWrap` and `newText` / `Text:set` / `add` / `addf`. `print` draws one segment per
  colour, each multiplied by the current colour, and moves on by the segment's width; `printf` and the
  measuring calls use the joined strings (a coloured `printf` draws in the current colour). Balatro's main
  menu builds its texts this way and failed in `love.load` with `bad argument #2 to 'textwidth'`.

### 2026-11-17, branch `perf/3ds-draw`

- lpp-3ds quad draw keeps the whole-texel inset rectangle on the quad (as lpp-vita does) instead of calling
  `getViewport` and recomputing it on every draw; `setViewport` and `setTextureInset` invalidate it. Measured
  inside a frame on the mock: 398 to 354 instructions per quad draw. The 3DS frame is still not in
  `frame_cost.lua` (draws need an open GPU frame).

### 2026-11-17, branch `fix/canvas-pixel-size`

- `Canvas` answers `getPixelWidth`, `getPixelHeight` and `getPixelDimensions`, as every LÖVE 11.5 Texture
  does. Balatro through the wrapper died on its first `love.draw` without them; it now runs. First frame-rate
  numbers for the real game are in `docs/PERFORMANCE_FINDINGS.md` (section 7).

### 2026-11-17, branch `perf/event-keyboard`

Input audit (event, keyboard, the four `updatecontrols`):

- Only the Vita front-touch poll allocated per frame (a table for the frame plus one per finger, about 384
  bytes with two fingers down). It now swaps two id-keyed tables and reuses the finger point tables: 0 bytes
  per frame with a held finger. The press, move and release edges are covered by `mainloop_test`.
- `event` and `keyboard` allocate nothing per frame; the key tracker allocates only when a key goes stale.

### 2026-11-17, branch `perf/ps3-draw`

PS3 draw path:

- New optional hook `gfx.prims.fillRuns(runs, dx, dy, color)`: `core/primitives` hands a cached polygon fill
  over in one call when the backend has it. PS3 emits the scanline rectangles as tiny3D QUADS batches of at
  most 64 quads (one `SetPolygon`/`End` per batch, not per rectangle). Synthetic frame polygon fill x54:
  112493 to 77285 instructions. The mock cannot show whether the real player accepts a long QUADS batch;
  the cap is a guess below the usual tiny3D command buffer, to be checked on RPCS3 or hardware.
- PS3 `draw`: no per-call closure for rotated quads, quad viewport read from its fields, no `math.abs`.
  Synthetic frame 196182 to 159968 instructions (PS3 baseline updated).
- PS3 quads cache their UVs (cleared by `setViewport`): 315 to 301 instructions per quad draw, synthetic frame
  159968 to 158232.

### 2026-11-16, branch `perf/main-loop`

Main loop (plan 3.5 / W12):

- The four `whileloop.lua` files (OneLua, lpp-vita, PS3, 3DS) reuse their `held` and `physical` input tables
  every frame instead of building two per frame; every key of the layout is written again each frame, so
  nothing carries over. `updatecontrols` on OneLua allocates under 100 bytes per frame in the mock.
- New option `lv1luaconf.frameskip` (default 0, off): `lv1lua.core.shouldDraw()` lets the main loop in
  `script.lua` skip `love.draw` after a frame whose update ran two or more slices, at most that many times in
  a row, so a console that is behind spends the time on updates. It never skips with
  `updaterate = "variable"`. New `tests/mainloop_test.lua`.
- `core/step` builds no tables per frame (read, not measured). `event.pump` and `keyboard` were not audited
  for per-frame garbage. The stall clamp already existed (`maxframeskip`).

### 2026-11-16, branch `perf/compact-batches`

`SpriteBatch`, `ParticleSystem` and `Text` (plan 3.4 / W11), measured with the new
`tests/bench/batch_cost.lua` (PSP backend, 200 sprites or particles):

| | before | after |
|---|---|---|
| `SpriteBatch:add` x200 | 6,417 instr, 81,152 B | 8,217 instr, 192 B |
| `SpriteBatch` draw (200) | 30,645 instr | 30,254 instr |
| `ParticleSystem:update` (200) | 4,020 instr, 4,248 B | 4,625 instr, 88 B |
| `Text` draw (10 strings) | 212 B | 124 B |

- A `SpriteBatch` keeps its sprites in parallel arrays instead of one table per sprite, builds its replay
  function once, and `clear` resets a count. A field a game leaves out costs no slot. The instruction count of
  `add` rises about 28% (more stores per call) while the garbage per sprite falls from about 400 B to none,
  which matters more on a 32MB device whose collector has to chase it.
- `ParticleSystem` compacts its live list in place (order kept) and reuses the tables of dead particles, so a
  steady system allocates nothing per frame; `update` builds no `alive` table. `Text` builds its replay closure
  once.
- `SpriteBatch:getColor` returned only the red channel (`and` cut the multiple return); it returns all four.
- `SpriteBatch:set` ignores an id outside the batch (it already did for an unknown id; it now also ignores a
  non-number). New `tests/batch_compact_test.lua`; byte budgets are asserted on PUC Lua only, because LuaJIT
  counts trace memory in `collectgarbage("count")`.

### 2026-11-16, branch `perf/capability-detection`

- New `OneLua/native.lua` (plan 2.5 / W14): `lv1lua.core.probeNative()` probes once which of `image.copyscale`,
  `resize`, `rotate`, `center`, `fliph`, `flipv`, `copy`, `blittint`, `blitadd`, `blitsub` and `screen.clip`
  the running OneLua build ships, and fills `lv1lua.native` (also `love._backend.native`) with booleans plus
  `scaling` (copyscale, or resize and clip).
- The per-draw `type(image.blitadd)` test in `blitImage` and the `image.copyscale` lookups in `imagedraw`
  read the probe instead. A build with no `blittint` draws a tinted image with the plain blit instead of
  raising; a build that cannot scale draws scaled images at natural size and warns once.
  Tests that change the SDK after loading call `lv1lua.core.probeNative()`. New `tests/native_probe_test.lua`.

### 2026-11-16, branch `perf/lppvita-draw`

lpp-vita draw path (plan 3.2 / W2). Both draw forms already map to one native call
(`Graphics.drawImageExtended`, rotation and scale on the GPU), so what was left was the Lua around it:

- An Image is recognised by its metatable before the draw-object registry is asked.
- A quad keeps its whole-texel inset rectangle (`_tx.._th`, stamped `_tg`); `setViewport` clears the stamp
  and `setTextureInset` bumps `lv1lua.gfx.insetGen`, as on OneLua. The per-draw `getViewport` call and the
  rounding in `insetQuadTexels` are gone.
- An unrotated draw computes its centre and scissor box without trigonometry and asks `scissorRejects` only
  while a scissor is set; `compose` re-flattens the transform only when it changed.
- `draw(img, x, y)` 208 -> 170 and `draw(img, quad, x, y)` 357 -> 192 instructions (target 200); the
  synthetic frame 115,025 -> 97,142 (-15.5%). Baseline updated. New `tests/lppvita_draw_fast_test.lua`.

### 2026-11-16, branch `perf/scaled-draw`

- `clipBlit` (scaled, mirrored and rotated draws on EBOOTs without `copyscale`) works with local math
  functions, skips the turned-bounds computation for an upright draw, and no longer re-flattens the transform
  it already has. Scaled quad on PSP 389 -> 352 instructions, scaled and rotated 484 -> 462; synthetic frame
  PSP 100,968 -> 99,462. The native call sequence (clip, resize, rotate, blit, resize, clip) is unchanged:
  it is the next target (batching).

### 2026-11-16, branch `perf/draw-specialisation`

OneLua draw path (Vita and PSP share `OneLua/imagedraw.lua`), plan 3.1 / W1:

- An Image is recognised by its metatable before the draw-object registry is asked, so the common draw
  skips two lookups.
- A quad keeps its inset rectangle (`_ix.._ih`, stamped `_ig`); `setViewport` clears the stamp and
  `setTextureInset` bumps `lv1lua.gfx.insetGen`, so neither can leave a stale rectangle. The per-draw
  `getViewport` call and `insetQuad` are gone.
- A quad draw at scale 1 takes a short path to `image.blit` (origin shift, no `abs`, no copy lookup).
- The sheet's last native rotation is remembered per image: an upright draw after an upright draw makes no
  `image.rotate` call (about 11 microseconds each on the SDK, measured in PPSSPP).
- `draw(img, x, y)` 185 -> 153 and `draw(img, quad, x, y)` 216 -> 145 instructions on PSP (244 -> 173 on
  OneLua); the synthetic frame PSP 107,696 -> 100,968 (-6.2%), OneLua 102,129 -> 96,100 (-5.9%).
  Baselines updated. New `tests/draw_fast_test.lua`.

### 2026-11-16, branch `perf/filesystem-manifest`

- `love.filesystem` keeps what it learns about a path (exists, directory, size) and each directory listing
  (plan 2.6 / W13; a native stat or listing costs about 11 ms on OneLua in PPSSPP). `read`, `getInfo`,
  `isFile`, `isDirectory`, `load` and `getRealDirectory` ask the SDK once per path instead of two to four
  times per call. The game directory is read-only and cached for good; the save directory is cached until the
  wrapper writes, appends, removes, creates a directory, opens or writes a `File` for writing, or changes
  identity. `getDirectoryItems` merges cached listings and returns a fresh table each call.
- A file another program adds to the save directory after a lookup stays unseen;
  `lv1lua.core.dropFilesystemCache()` clears the save answers. New `tests/fs_cache_test.lua`.

### 2026-11-16, branch `perf/polygon-cache-bounds`

- `love.graphics.rectangle` honours `rx`, `ry` and `segments` (they were ignored, so rounded boxes drew
  sharp). The corner points are cached per size and radii and filled through the polygon cache, so a rounded
  box costs the same as any cached polygon fill. Radii clamp to half the size, `ry` defaults to `rx`.
- The polygon fill cache keeps no entry above 512 rectangles (the shape is still drawn), so one large shape
  cannot take the memory of a 32MB device.
- `lv1lua.core.polygonCacheStats()` returns `{hit, miss, skipped}`; `tests/bench/frame_cost.lua` prints them
  per frame (synthetic frame: 54 hits, 0 misses). New `tests/polygon_cache_test.lua`. Synthetic frame +0.2%
  from the hit counter.

### 2026-11-16, branch `perf/onelua-rotation-snap`

- New option `lv1luaconf.rotatesnap` (degrees, default off, plan 2b.2 / W25): on OneLua (Vita and PSP) a draw
  turned by less than the angle is drawn upright, so a scaled quad skips `image.center` (twice), the turned
  bounds trigonometry and the native rotation. Off by default because it changes pixels slightly.

### 2026-11-06, branch `perf/wrapper-hot-paths`

Hot paths of the shared graphics layer, measured with the new `tests/bench/` scripts (Lua 5.1, count hook:
VM instructions and bytes allocated per `love.graphics` call on the test mocks; a console runs roughly
3M VM instructions per second, so 100 instructions is ~30 microseconds).

| call (PSP backend) | instructions before -> after | bytes allocated before -> after |
|---|---|---|
| `setColor(r,g,b,a)` | 92 -> 37 | 352 -> 0 |
| `push/translate/pop` | 165 -> 175 | 704 -> 0 |
| `draw(img, quad, ...)` | 229 -> 213 | 0 |
| `draw` quad scaled + rotated (no `copyscale`) | 590 -> 523 | 513 -> ~1 |

- `setColor` updates the RGBA tuple in place, returns early for an unchanged colour and memoises native
  colour handles (bounded to 1024 entries); `util.to255` caches `math.floor`.
- The transform stack recycles popped levels instead of allocating a table per `push`.
- `imagedraw`: `fold` skips the method call while the transform is clean, `rotate` multiplies by a constant,
  `isDrawObject`/`isImage` are upvalues, and the turned-bounds computation allocates nothing.
- New: `tests/bench/vm_cost.lua`, `vm_profile.lua`, `alloc_cost.lua`, `tests/hotpath_test.lua`.
- **`polygon("fill")` was the biggest wrapper cost**: the scanline rasteriser ran in Lua on every call
  (~2,700 VM instructions for a 5-point shape on PSP, ~4,800 on PS3, tens of thousands for a rounded box).
  Fills are now computed once per vertex table as merged rectangles (`core/polyfill.lua polygonRuns`), cached
  in a weak table with a fingerprint of the vertices and of the transform (integer translations reuse the
  cache with a shift), and drawn with one native `fillRect` per rectangle instead of one per scanline.
  Synthetic Balatro-sized frame (`tests/bench/frame_cost.lua`: 213 push/pop, 168 setColor, 124 draws, 54
  polygon fills, 45 prints): PSP 243k -> 122k instructions, OneLua 223k -> 102k, lpp-vita 237k -> 115k,
  PS3 344k -> 195k; garbage per frame 29 KB -> 2 KB (PSP).
- New: `tests/bench/frame_cost.lua` (+ `frame_baseline.lua`, `--check`, `--sections`), `api_coverage.lua`,
  `tests/polyfill_runs_test.lua`. Two `primitives_test` expectations changed: a filled square is now one
  10x10 rectangle instead of ten 1px spans (same pixels).
- CI runs `tests/bench/frame_cost.lua --check` on Lua 5.1 and fails when a backend gets more than 10% worse than
  `frame_baseline.lua`.
- `Font:getWidth` caches the native measure per font and string (bounded to 256 entries). Games that call
  `getWidth` every frame no longer cross into the SDK for a string they already measured. The synthetic frame
  does not call `getWidth`, so its numbers do not change.
- `circle` and `ellipse` build their points once per radii and segment count, relative to the centre (bounded
  to 64 tables), and `polygon` places them with an origin offset, so the polygon fill cache hits at every
  position. PS3 `circle("fill")` 17,300 -> 2,044 instructions; the synthetic frame grows 0.2-0.5% from the
  extra origin mapping in `polygonFill`. Only backends without a native `fillCircle` (PS3) gain on fills; the
  outline path of every backend skips the trigonometry.
- 3DS `print` reuses its queued line tables across frames and skips the line split for text without a newline
  (bench `print` outside a frame 261 -> 242 instructions; the in-frame path allocates no table per call).
  `setColor` on the 3DS already shares the memoised path (37 instructions).
- PSP `pop` no longer flattens the transform and calls `screen.clip()` every time. `applyScissor` runs on `pop`
  only when the popped level held a scissor, and the PSP hook skips the native call when the clip rectangle is
  unchanged (`imagedraw` forces the restore after its own clip). `push/translate/scale/pop` x213 on the
  synthetic frame: 41,759 -> 26,210 instructions; the PSP frame 122,997 -> 107,696 (-12.4%).
  `tests/bench/frame_baseline.lua` PSP updated to the new number. Other backends pay one extra check in `pop`
  (+0.4 to 0.7%).

### 2026-11-06, branch `fix/onelua-no-copyscale`

The `EBOOT.PBP` in the repo root is the stock ONElua v4R1 build and has no
`image.copyscale` (issue #3), so any scaled draw failed on the PSP. Measured on
that EBOOT in PPSSPP: `image.resize` scales a whole-image blit on the GPU,
`image.scale` changes nothing visible, a sub-rect blit ignores both and draws
1:1, `screen.clip(x, y, w, h)` clips every later draw and `screen.clip()` resets
it, and `image.center(img, cx, cy)` (unscaled sheet pixels) moves the rotation
pivot, which is the blit's top-left corner by default.

**Fixed**
- Scaled and mirrored draws on builds without `image.copyscale`: the sheet is
  resized to its final size, blitted whole and clipped to the destination
  rectangle (`OneLua/imagedraw.lua`). No per-scale copy is built, so scale
  animations cost no memory. Mirroring uses one cached flipped copy of the
  sheet per axis pair. The shared sheet's size is restored after each draw.
  Builds that have `copyscale` keep the old path.
- `love.graphics.draw(image, quad, x, y, r, sx, sy, ox, oy)` dropped `oy` on
  the OneLua backends (the quad form has nine arguments, the function took
  eight), so a quad's y origin never applied.
- PSP scissor: `setScissor`/`intersectScissor` now drive `screen.clip`
  (`OneLua/psp/scissor.lua`); before, getScissor answered but nothing clipped.

**Known limits of the clip path**
- A rotated draw of a quad cut from a larger sheet clips to the turned
  bounding box, so neighbouring sheet pixels can show in its corners.
- Each scaled draw changes the GPU clip rectangle; many tiny scaled draws per
  frame cost more than the same draws unscaled.

**Tests**
- `tests/noscale_test.lua` (scale, mirror, rotate, scissor, restore) and a
  quad-origin case in `tests/quad_draw_test.lua`; the OneLua mock gained
  `image.copy`, `image.center` and `screen.clip`.

### 2026-10-29, branch `feat/desanim8-1.0.0`

The bundled `game/libraries/desAnim8.lua` is now the `dist/desAnim8.lua`
single-file build of desAnim8 v1.0.0 (the library is split into modules
upstream and packed with a private `require`, so `require 'libraries.desAnim8'`
and the 0.5.0 API are unchanged). No wrapper code changed: the build draws
through `love.graphics.draw(image, quad, ...)` and the state calls the backends
already provide.

**New in the bundled library** (see the desAnim8 changelog for the full list)
- Playback: `setSpeed`, `setLoopRange`, `setPlayMode`, `setDurations`, markers,
  `onFrame`, queries (`getPhase`, `isFinished`, ...), `getState`/`setState`.
- Atlas and Aseprite import, `newSet`, `newComposite`, `newBatch`,
  `addToBatch`/`setInBatch` for `love.graphics.newSpriteBatch`.
- Render style: `setColor`, `setAlpha`, `setBlendMode`, `flash`, trail, onion
  skin, pixel snap, `drawBounds`.

**Tests**
- `tests/desanim8_test.lua` also runs on the 3DS mock, and checks that a styled
  draw restores colour and blend mode, that trail/onion/bounds/timeline draw,
  that `addToBatch` feeds a SpriteBatch, and that loading leaks no global.

**Known limits** (backend, not library)
- Tint, `flash` and `setBlendMode` follow the backend's own colour and blend
  support (OneLua tints alpha only on quads; see Known limitations).
- `setShader` is accepted and has no visible effect (Shader is a stub).

### 2026-10-09, branch `fix/update-desanim8`

The bundled `game/libraries/desAnim8.lua` was a v0.1.0 fork. It is now the
upstream desAnim8 v0.5.0 (single file, same `love.graphics.draw(image, quad,
...)` path on every backend, so no wrapper changes).

**Fixes inherited from desAnim8**
- A flipped animation drawn with a uniform scale (`anim:flipH():draw(...)` with
  only `sx` given) squashed the sprite; an omitted `sy` now follows `sx`.
- `update` ignores a negative, NaN or infinite `dt` instead of rewinding the
  animation or freezing it for good.
- Grid column and row counts account for `left`, `top` and `border`.
- Errors are raised at the caller's line, with the argument named.

**New**
- Play modes `'loop'`, `'once'`, `'bounce'`, `'bounceOnce'` as the third argument
  of `newAnimation`, and `anim.onLoop` (function or method name) for callbacks.
  `setFlipH`, `setFlipV`, `getFrameCount`, `getDuration`, `getPlayMode`.

**Changed**
- The third argument of `newAnimation` is a play mode string, not an `onLoop`
  value. The old `{ once = true, onComplete = fn }` table is gone: use
  `newAnimation(frames, dur, 'once')` and set `anim.onLoop = fn`.
  `desAnim8.new(image, fw, fh, numFrames, dur, iw, ih)` and `anim:draw(x, y)`
  keep working, and now return a normal animation instead of a proxy object.
- `tests/desanim8_test.lua` covers play-once through the new API, bounce, flip
  scale and the `dt` guard, on all four backend mocks.

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
