# Platform SDK API cheat-sheet

Native APIs each backend calls, grounded in the SDK sources. Read before touching a backend or its mock.

### OneLua (Vita and PSP)
| Category | API |
|---|---|
| Images | `image.load / blit / blittint / blitadd / blitsub (PSP) / copyscale / rotate / fliph / flipv / setfilter / getrealw / getrealh` |
| Screen | `screen.print / clear / flip / textwidth` |
| Drawing | `draw.fillrect / rect / line / circle` |
| Font | `font.load / setdefault` |
| Sound | `sound.load / play / stop / pause / vol / playing / looping / loop` |
| Input | `buttons.read / held / analoglx …`, `touch.read / front` (Vita), `osk.init` |
| Colour | `color.new(r, g, b, a)` (0-255), `color.a(c)` |
| Timer | `timer.new()` → `t:time() / reset() / start()` |
| Files | `files.exists / mkdir / delete / list / isdir` |
| OS | `os.delay / os.restart / os.cfw / os.language / os.nick` |

### lpp-vita (grounded in `source/lua*.cpp`)
| Category | API |
|---|---|
| Graphics | `Graphics.loadImage / drawScaleImage / drawImageExtended(cx, cy, tex, st_x, st_y, w, h, rad, sx, sy, color) / fillRect / fillEmptyRect / drawLine / fillCircle / setImageFilters / freeImage` |
| Font | `Font.load / setPixelSizes (integer) / print / getTextWidth` |
| Sound | `Sound.open / play(h, loop) / pause / resume / close / isPlaying / setVolume (integer 0-32767) / getVolume`; no stop, `play` resets the volume |
| Input | `Controls.read / check / getLeftX … / getEnterButton`, `Keyboard.start / getState / getInput` |
| Colour | `Color.new(r, g, b, a)` |
| Timer | `Timer.new / getTime / reset / delay` |
| System | `System.doesFileExist / doesDirExist / listDirectory / createDirectory / deleteFile / getLanguage / getUsername / getBatteryPercentage / exit / launchEboot` |

### lpp-3ds (grounded in `source/lua*.cpp`; see `tests/mock_3ds.lua`)
| Category | API |
|---|---|
| Frame | `Screen.refresh` → `Graphics.initBlend(TOP_SCREEN)` → GPU draws → `Graphics.termBlend` → CPU text → `Screen.flip` |
| Graphics | `fillRect / fillEmptyRect / drawLine (x1, x2, y1, y2, color)`, `drawCircle(x, y, r_int, color)`, `drawScaleImage(x, y, tex, sx, sy, color)`, `drawImageExtended(cx, cy, st_x, st_y, w, h, rad, sx, sy, tex, color)`, `setViewport` (scissor) |
| Font | `Font.load / setPixelSizes / measureText / print(font, x, y, text, color, screen)` |
| Sound | `Sound.openWav / openOgg / openAiff(path, streamed)`, `play(h, loop) / pause / resume / isPlaying / getTotalTime` |
| Input | `Controls.read / check(pad, KEY_*) / readCirclePad` |
| Files | `System.openFile(path, FREAD / FWRITE / FCREATE) / readFile / writeFile / getFileSize / closeFile`, `doesFileExist` (files only), `listDirectory` |

> **lpp-3ds gotchas.** `TOP_SCREEN` is `0`. `Color.new` returns an integer.
> `drawImageExtended` takes the texture **tenth** and the sprite **centre**.
> `luaL_checkinteger` (Lua 5.3) raises on a fractional source origin, radius,
> font size or print position. The player rebinds `io.open` / `io.read` /
> `io.write` / `io.close`, so shared code opens files through `lv1lua.fileio`,
> never `io.open`.

### PS3 Lua Player
| Category | API |
|---|---|
| Graphics | `InitGFX / StartGFX / FlipGFX / EndGFX`, tiny3D `gfx.LoadTexture / SetTexture / SetPolygon / VertexPosition / VertexTexture / VertexColor / End / BlendFunction / FontAddTTF / FontSetSize / FontSetColors / FontDrawString / Mode2D` |
| Sound | `snd.Init / SetVoice / PlayVoice / StopVoice / FreeVoice / SetVolumeBGMusic / Finalize` (one background voice) |
| Input | `pad.circle / cross / triangle / square / L1 / R1 / up / down / left / right / select / start / L3 / R3 / lx / ly / rx / ry (0)` |
| System | `sys.TimerUsleep / UtilRegisterCallback / UtilCheckCallback / SYSUTIL_EXIT_GAME` (no timer) |
