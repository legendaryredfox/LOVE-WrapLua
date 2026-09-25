-- lpp-vita graphics: print. Wrapping, alignment and line spacing are shared
-- (core/text.lua).

-- Font.print takes the native handle, not our wrapper.
local function nativeFont()
    local f = lv1lua.current.font
    return type(f) == "table" and f._font or f
end

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    x, y = x or 0, y or 0
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s
    end
    Font.print(nativeFont(), x, y, text, lv1lua.current.color)
end
