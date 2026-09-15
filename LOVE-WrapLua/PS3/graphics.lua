-- love.graphics for the PS3 backend (PS3 Lua Player).
--
-- Entry point only: each submodule owns one area of the API. `state` loads
-- first because it brings up the native layer (InitGFX/InitFont) and defines
-- lv1lua.gfx / lv1lua.current.
--
-- This is the least-supported backend: no transforms, no primitives, no
-- offscreen rendering. See Implemented.md.

if not lv1lua.load then
    dofile((lv1lua.dataloc or "") .. "LOVE-WrapLua/core/loader.lua")
end

lv1lua.loadOnce("LOVE-WrapLua/core/util.lua")
lv1lua.loadOnce("LOVE-WrapLua/core/textwrap.lua")

local GRAPHICS = "LOVE-WrapLua/PS3/graphics/"

lv1lua.load(GRAPHICS .. "state.lua")
lv1lua.load(GRAPHICS .. "transform.lua")
lv1lua.load(GRAPHICS .. "image.lua")
lv1lua.load(GRAPHICS .. "font.lua")
lv1lua.load(GRAPHICS .. "text.lua")
lv1lua.load(GRAPHICS .. "primitives.lua")
lv1lua.load(GRAPHICS .. "objects.lua")
lv1lua.load(GRAPHICS .. "info.lua")
