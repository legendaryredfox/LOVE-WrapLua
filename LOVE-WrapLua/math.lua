-- love.math — backend-agnostic, pure Lua.
--
-- Entry point only: one module per area of the API.

if not lv1lua.load then
    dofile((lv1lua.dataloc or "") .. "LOVE-WrapLua/core/loader.lua")
end

lv1lua.load("LOVE-WrapLua/math/random.lua")
lv1lua.load("LOVE-WrapLua/math/noise.lua")
lv1lua.load("LOVE-WrapLua/math/transform.lua")
lv1lua.load("LOVE-WrapLua/math/geometry.lua")
lv1lua.load("LOVE-WrapLua/math/color.lua")
