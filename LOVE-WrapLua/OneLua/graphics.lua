-- love.graphics for the OneLua backend (PSP + Vita).
--
-- This file only wires the pieces together; each submodule owns one area of the
-- API. Load order matters:
--   state      defines lv1lua.gfx / lv1lua.current, which the rest read
--   transform  creates the transform stack (draw, text and primitives use it)
--   font       needs newFont before it can install the default font
--
-- Loading this file is the whole public entry point: everything lands on
-- love.graphics.

if not lv1lua.load then
    dofile((lv1lua.dataloc or "") .. "LOVE-WrapLua/core/loader.lua")
end

lv1lua.load("LOVE-WrapLua/core/util.lua")
lv1lua.load("LOVE-WrapLua/core/transform.lua")
lv1lua.load("LOVE-WrapLua/core/textwrap.lua")

local GRAPHICS = "LOVE-WrapLua/OneLua/graphics/"

lv1lua.load(GRAPHICS .. "state.lua")
lv1lua.load(GRAPHICS .. "transform.lua")
lv1lua.load(GRAPHICS .. "image.lua")
lv1lua.load(GRAPHICS .. "draw.lua")
lv1lua.load(GRAPHICS .. "font.lua")
lv1lua.load(GRAPHICS .. "text.lua")
lv1lua.load(GRAPHICS .. "primitives.lua")
lv1lua.load(GRAPHICS .. "canvas.lua")
lv1lua.load(GRAPHICS .. "spritebatch.lua")
lv1lua.load(GRAPHICS .. "textobject.lua")
lv1lua.load(GRAPHICS .. "mesh.lua")
lv1lua.load(GRAPHICS .. "particles.lua")
lv1lua.load(GRAPHICS .. "info.lua")
