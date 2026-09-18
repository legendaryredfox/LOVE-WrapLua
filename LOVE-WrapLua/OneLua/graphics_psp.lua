-- love.graphics for the PSP (OneLua on a 480x272 screen).
--
-- The PSP runs the same SDK as the OneLua Vita build, but with the PGF system
-- font, a different scale factor and no transform support, so it gets its own
-- thin backend in psp/ rather than branching the Vita modules.
--
-- Entry point only: `state` loads first (it defines lv1lua.gfx /
-- lv1lua.current), and `font` before `text` so printf can measure.

if not lv1lua.load then
    dofile((lv1lua.dataloc or "") .. "LOVE-WrapLua/core/loader.lua")
end

lv1lua.loadOnce("LOVE-WrapLua/core/util.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/textwrap.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/polyfill.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/capabilities.lua")

local GRAPHICS = "LOVE-WrapLua/OneLua/psp/"

lv1lua.load(GRAPHICS .. "state.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/texinset.lua")
lv1lua.load(GRAPHICS .. "transform.lua")
lv1lua.load(GRAPHICS .. "image.lua")
lv1lua.load(GRAPHICS .. "font.lua")
lv1lua.load(GRAPHICS .. "text.lua")
lv1lua.load(GRAPHICS .. "primitives.lua")
lv1lua.load(GRAPHICS .. "objects.lua")
lv1lua.load(GRAPHICS .. "info.lua")
