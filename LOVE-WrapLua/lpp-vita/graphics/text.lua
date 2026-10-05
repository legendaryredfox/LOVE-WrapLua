-- lpp-vita graphics: print. Wrapping, alignment and line spacing are shared
-- (core/text.lua).

local stack = lv1lua.gfx.transform

-- Font.print takes the native handle, not our wrapper.
local function nativeFont()
    local f = lv1lua.current.font
    if type(f) == "table" then return f._font, f.size end
    return f, nil
end

-- The anchor follows the transform stack. Font.print has no size argument: the
-- pixel size lives on the handle, so a scaled print sets it for the call and
-- puts the font's own size back afterwards.
function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    stack:updateTransform()
    local t = stack.transform
    x = (x or 0) * t._scaleX + t._offsetX
    y = (y or 0) * t._scaleY + t._offsetY
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s
    end
    local handle, size = nativeFont()
    local k = (t._scaleX + t._scaleY) / 2
    local scaled = size and k ~= 1
    if scaled then Font.setPixelSizes(handle, lv1lua.gfx.pixelSize(size * k)) end
    Font.print(handle, x, y, text, lv1lua.current.color)
    if scaled then Font.setPixelSizes(handle, lv1lua.gfx.pixelSize(size)) end
end
