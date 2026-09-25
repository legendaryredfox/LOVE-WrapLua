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

-- Audio namespace: one background voice bound per channel, re-issued each
-- frame by PlayVoice, as the PS3 Lua Player does.
snd = {
    Init             = nop,
    SetVoice         = function(...) __rec.log("snd.SetVoice", ...) end,
    PlayVoice        = function(...) __rec.log("snd.PlayVoice", ...) end,
    StopVoice        = function(...) __rec.log("snd.StopVoice", ...) end,
    FreeVoice        = function(...) __rec.log("snd.FreeVoice", ...) end,
    SetVolumeBGMusic = function(...) __rec.log("snd.SetVolumeBGMusic", ...) end,
}

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

-- Free graphics functions the frame loop uses.
FlipGFX = nop

-- System utility namespace (in-game XMB callbacks).
sys = {
    UtilRegisterCallback = nop,
    UtilCheckCallback    = function() return 0 end,
    SYSUTIL_EXIT_GAME    = 1,
    TimerUsleep          = nop,
}
g_status = 0

-- Controller state. Every button reads as a function returning 0 or 1, like
-- the real pad.* API; tests drive it through `pad._down`.
pad = setmetatable(
    {
        InitPads = nop,
        _down = {},
        lx = function() return 128 end, ly = function() return 128 end,
        rx = function() return 128 end, ry = function() return 128 end,
    },
    { __index = function(t, k)
        return function() return t._down[k] and 1 or 0 end
    end }
)
