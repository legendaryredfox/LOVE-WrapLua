-- love.graphics for the lpp-vita backend (PS Vita).
--
-- Entry point only: each submodule owns one area of the API. `state` must load
-- first (it defines lv1lua.gfx / lv1lua.current), and `font` must load before
-- `text` so printf has a font to measure with.

if not lv1lua.load then
    dofile((lv1lua.dataloc or "") .. "LOVE-WrapLua/core/loader.lua")
end

lv1lua.loadOnce("LOVE-WrapLua/core/util.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/transform.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/textwrap.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/polyfill.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/capabilities.lua")

local GRAPHICS = "LOVE-WrapLua/lpp-vita/graphics/"

lv1lua.load(GRAPHICS .. "state.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/state.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/texinset.lua")
lv1lua.load(GRAPHICS .. "transform.lua")
lv1lua.load(GRAPHICS .. "image.lua")
lv1lua.load(GRAPHICS .. "draw.lua")
lv1lua.load(GRAPHICS .. "font.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/font.lua")
lv1lua.load(GRAPHICS .. "text.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/text.lua")
lv1lua.load(GRAPHICS .. "primitives.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/primitives.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/objects.lua")
lv1lua.load(GRAPHICS .. "info.lua")
