-- Loads the platform backend plus the shared modules.
--
-- Backend modules come first: they define lv1lua.gfx / lv1lua.current, which
-- the shared ones read.

-- Every backend's whileloop calls lv1lua.core.step, so the accumulator has to
-- exist before one loads. loadOnce: script.lua already asked for it.
lv1lua.loadOnce("LOVE-WrapLua/core/timestep.lua")

local backend = "LOVE-WrapLua/" .. lv1lua.mode .. "/"

if lv1lua.isPSP then
    -- PSP runs OneLua too, but with its own thin graphics backend.
    lv1lua.load("LOVE-WrapLua/OneLua/graphics_psp.lua")
else
    lv1lua.load(backend .. "graphics.lua")
end

lv1lua.load(backend .. "whileloop.lua")
lv1lua.load(backend .. "timer.lua")
lv1lua.load(backend .. "audio.lua")
lv1lua.load(backend .. "event.lua")
lv1lua.load(backend .. "keyboard.lua")

lv1lua.load("LOVE-WrapLua/filesystem.lua")
lv1lua.load("LOVE-WrapLua/math.lua")
lv1lua.load("LOVE-WrapLua/system.lua")
lv1lua.load("LOVE-WrapLua/window.lua")
lv1lua.load("LOVE-WrapLua/joystick.lua")
lv1lua.load("LOVE-WrapLua/data.lua")
