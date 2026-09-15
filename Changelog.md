## Changelog

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
- `love.graphics.draw(image, quad, …)` only understands a quad on
  OneLua/Vita, so upstream `anim8` runs there and nowhere else (T2.1).
- `desAnim8` still calls the OneLua native `image.blit` directly, so it works
  on OneLua and PSP only. A rework is planned as T9.1, against a spec kept
  outside this repo.
- lpp-vita and PS3 have no transform stack yet (T2.2), and the GitHub CI runs
  are red for a billing lock on the account, not for a code failure.

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
