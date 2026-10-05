-- PSP graphics: print. Wrapping, alignment and line spacing are shared
-- (core/text.lua).

local stack = lv1lua.gfx.transform

-- The anchor follows the transform stack like every other draw, and the glyph
-- size takes the mean of the two axis scales (screen.print has one size).
function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    stack:updateTransform()
    local t = stack.transform
    x = (x or 0) * t._scaleX + t._offsetX
    y = (y or 0) * t._scaleY + t._offsetY
    local fontsize = lv1lua.current.font.size / lv1lua.gfx.fontUnit
                     * (t._scaleX + t._scaleY) / 2
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x = x * lv1lua.gfx.scale
        y = y * lv1lua.gfx.scale
        fontsize = fontsize * lv1lua.gfx.fontScale
    end
    screen.print(lv1lua.current.font.font, x, y, text, fontsize, lv1lua.current.color)
end
