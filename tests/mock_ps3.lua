-- PS3 (tiny3D / PSL1GHT homebrew) native API mock — least-supported tier.
-- Load after mock_common.lua.  PS3 exposes a grab-bag of free functions and a
-- `surface` object; here they are permissive no-op stubs, just enough for the
-- PS3 backend modules to load and run under the shared test suite.

lv1lua.mode = "PS3"
love._console_name = "PS3"

local function nop() end

-- Free graphics/system functions.
InitGFX          = nop
StartGFX         = nop
InitFont         = nop
BlitToScreen     = function(...) __rec.log("BlitToScreen", ...) end
DrawText         = function(...) __rec.log("DrawText", ...) end
TimerUsleep      = nop
quit             = function() lv1lua.running = false end
showTextInput    = function() return "" end
UtilRegisterCallback = nop
UtilCheckCallback    = nop

-- Audio free functions.
playsound        = nop
StopVoice        = nop
SetVoice         = nop
SetVolumeBGMusic = nop

-- Graphics namespace (PS3 exposes only fillRect natively).
Graphics = { fillRect = function(...) __rec.log("Graphics.fillRect", ...) end }

-- surface() constructor — returns an object whose unknown methods no-op.
function surface()
    local s = { _w = 64, _h = 64 }
    function s:LoadIMG(path) self._path = path; __rec.log("surface.LoadIMG", path) end
    function s:draw(...) __rec.log("surface.draw", ...) end
    function s:getWidth()  return self._w end
    function s:getHeight() return self._h end
    return setmetatable(s, { __index = function() return function() return 0 end end })
end

-- Controller state.
pad = setmetatable(
    { InitPads = nop, lx = 128, ly = 128, rx = 128, ry = 128 },
    { __index = function() return function() return false end end }
)
