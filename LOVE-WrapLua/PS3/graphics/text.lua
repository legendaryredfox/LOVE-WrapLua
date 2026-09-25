-- PS3 graphics: print. Wrapping, alignment and line spacing are shared
-- (core/text.lua).

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    x = (x or 0) * lv1lua.gfx.scale
    y = (y or 0) * lv1lua.gfx.scale + lv1lua.gfx.yOffset
    DrawText(x, y, text)
end
