-- PS3 graphics: print and printf.

local core = lv1lua.core

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    x = (x or 0) * lv1lua.gfx.scale
    y = (y or 0) * lv1lua.gfx.scale + lv1lua.gfx.yOffset
    DrawText(x, y, text)
end

function love.graphics.printf(text, x, y, wrapWidth, align)
    if not text or text == "" then return end
    align = align or "left"
    wrapWidth = wrapWidth or lv1lua.screenWidth

    local lineH   = 14
    local measure = core.fontMeasure(lv1lua.current.font, 8)

    for i, line in ipairs(core.wrapText(text, wrapWidth, measure)) do
        local ox = core.alignOffset(align, measure(line), wrapWidth)
        love.graphics.print(line, x + ox, y + (i - 1) * lineH)
    end
end
