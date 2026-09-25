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

-- tiny3d namespace. The player binds tiny3d_BlendFunc as gfx.BlendFunction and
-- puts its constants on this table; the values below are the ones tiny3d.h
-- defines (RGB in the low half, alpha in the high half), so a wrapper that
-- combines the wrong pair fails here.
gfx = {
    BlendFunction = function(...) __rec.log("gfx.BlendFunction", ...) end,

    BLEND_FUNC_SRC_RGB_ZERO                  = 0x00000000,
    BLEND_FUNC_SRC_RGB_ONE                   = 0x00000001,
    BLEND_FUNC_SRC_RGB_SRC_ALPHA             = 0x00000302,
    BLEND_FUNC_SRC_RGB_DST_COLOR             = 0x00000306,
    BLEND_FUNC_SRC_ALPHA_ZERO                = 0x00000000,
    BLEND_FUNC_SRC_ALPHA_ONE                 = 0x00010000,
    BLEND_FUNC_SRC_ALPHA_SRC_ALPHA           = 0x03020000,
    BLEND_FUNC_SRC_ALPHA_DST_ALPHA           = 0x03040000,

    BLEND_FUNC_DST_RGB_ZERO                  = 0x00000000,
    BLEND_FUNC_DST_RGB_ONE                   = 0x00000001,
    BLEND_FUNC_DST_RGB_ONE_MINUS_SRC_COLOR   = 0x00000301,
    BLEND_FUNC_DST_RGB_ONE_MINUS_SRC_ALPHA   = 0x00000303,
    BLEND_FUNC_DST_ALPHA_ZERO                = 0x00000000,
    BLEND_FUNC_DST_ALPHA_ONE                 = 0x00010000,
    BLEND_FUNC_DST_ALPHA_ONE_MINUS_SRC_COLOR = 0x03010000,
    BLEND_FUNC_DST_ALPHA_ONE_MINUS_SRC_ALPHA = 0x03030000,

    BLEND_RGB_FUNC_ADD                       = 0x00008006,
    BLEND_RGB_FUNC_SUBTRACT                  = 0x0000800A,
    BLEND_RGB_FUNC_REVERSE_SUBTRACT          = 0x0000800B,
    BLEND_RGB_MIN                            = 0x00008007,
    BLEND_RGB_MAX                            = 0x00008008,
    BLEND_ALPHA_FUNC_ADD                     = 0x80060000,
    BLEND_ALPHA_FUNC_SUBTRACT                = 0x800A0000,
    BLEND_ALPHA_FUNC_REVERSE_SUBTRACT        = 0x800B0000,
    BLEND_ALPHA_MIN                          = 0x80070000,
    BLEND_ALPHA_MAX                          = 0x80080000,
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
