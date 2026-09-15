-- PSP graphics: print and printf.

local core = lv1lua.core

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

-- The PGF system font is near enough fixed-pitch at the sizes the PSP uses,
-- but width still comes from the font object so a size change is reflected.
local LINE_HEIGHT = 16

function love.graphics.printf(text, x, y, width, align)
    if not text or text == "" then return end
    align = align or "left"
    width = width or lv1lua.screenWidth

    local measure = core.fontMeasure(lv1lua.current.font, 8)

    for i, line in ipairs(core.wrapText(text, width, measure)) do
        local ox = core.alignOffset(align, measure(line), width)
        love.graphics.print(line, x + ox, y + (i - 1) * LINE_HEIGHT)
    end
end
