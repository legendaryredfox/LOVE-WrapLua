-- PSP graphics: print. Wrapping, alignment and line spacing are shared
-- (core/text.lua).

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    x, y = x or 0, y or 0
    local fontsize = lv1lua.current.font.size / lv1lua.gfx.fontUnit
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x = x * lv1lua.gfx.scale
        y = y * lv1lua.gfx.scale
        fontsize = fontsize * lv1lua.gfx.fontScale
    end
    screen.print(lv1lua.current.font.font, x, y, text, fontsize, lv1lua.current.color)
end
