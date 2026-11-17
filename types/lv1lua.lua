---@meta

-- Names that exist only in LOVE-WrapLua. The LÖVE 11 API itself comes from the love2d library
-- (`workspace.library` in .luarc.json); a wrapped function keeps that signature.

---@class lv1luaconf
---@field keyconf? "XB"|"XBA"|"PS"|"SE" Face button layout. Unknown values fall back to "XB" with a warning.
---@field imgscale? boolean Downscale images for small screens.
---@field resscale? boolean Downscale the whole resolution for small screens.
---@field updaterate? number|"variable" Fixed update rate in Hz, or "variable" for one update per frame.
---@field maxframeskip? integer Most update slices one frame may run. Default 5.
---@field frameskip? integer Most love.draw calls skipped in a row while love.update is behind. Default 0.
---@field rotatesnap? number Degrees below which a turn is drawn upright.
---@field lowmemory? number Lua heap in KB past which love.lowmemory is called. Off by default.
lv1luaconf = {}

---@class lv1lua.Core
---@field step fun(elapsed: number): integer Called once per frame by a backend's whileloop; returns the update slices run.
---@field shouldDraw fun(): boolean Asked before each love.draw (frameskip).
---@field getFPS fun(): number
---@field getAverageDelta fun(): number
---@field polygonCacheStats fun(): {hit: integer, miss: integer, skipped: integer}
---@field pumpTextInput? fun() 3DS only: shows the keyboard while it is open.
---@field tickVibration? fun(elapsed: number) Stops a timed vibration.

---@class lv1lua.Gfx
---@field transform table The software transform stack (core/transform.lua).
---@field lineWidth number
---@field lineStyle? "smooth"|"rough"
---@field lineJoin? "none"|"miter"|"bevel"
---@field pointSize? number
---@field scale number Display scale of the backend.
---@field applyScissor? fun(force?: boolean) Present when the backend clips on the GPU.
---@field scissorRejects fun(x: number, y: number, w: number, h: number): boolean
---@field beginFrame? fun() 3DS: opens the GPU frame.
---@field endFrame? fun() 3DS: closes the GPU frame and prints the deferred text.
---@field flushText? fun() 3DS: prints the text queued during the frame.
---@field takeScreenshot? fun() lpp-vita only.
---@field pendingShot? {path: string, format: integer} lpp-vita only.

---@class lv1lua
---@field mode "OneLua"|"lpp-vita"|"PS3"|"3DS"
---@field isPSP boolean True when OneLua runs on a PSP.
---@field dataloc string Prefix of every asset path.
---@field saveloc string Save directory.
---@field screenWidth integer
---@field screenHeight integer
---@field running boolean
---@field dt number The fixed slice the current love.update was called with.
---@field frameDelta number The real frame time.
---@field keyset string[] Face and shoulder button names: circle, cross, triangle, square, L, R.
---@field joystickState {axes: number[], buttons: boolean[], hats: string[]}
---@field current table Active graphics state: font, color, colorRGBA, bgcolor, canvas, blendMode.
---@field gfx lv1lua.Gfx
---@field core lv1lua.Core
---@field util table
---@field fileio? table File seam (3DS rebinds io).
---@field draw fun() Defined by a backend's whileloop: one frame of love.draw.
---@field update fun() Defined by a backend's whileloop: the fixed update slices.
---@field updatecontrols fun() Defined by a backend's whileloop: samples the pad.
---@field warn? fun(msg: string) Warning sink; override it to route warnings elsewhere.
---@field rumble? fun(strength: integer) Set by a backend whose SDK has a rumble call (0..255).
---@field exists fun(path: string): boolean
---@field load fun(path: string)
---@field loadOnce fun(path: string)
lv1lua = {}
