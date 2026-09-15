-- lpp-vita graphics: print and printf.

local core = lv1lua.core

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

function love.graphics.printf(text, x, y, wrapWidth, align)
    if not text or text == "" then return end
    align = align or "left"
    wrapWidth = wrapWidth or lv1lua.screenWidth

    local fnt     = lv1lua.current.font
    local lineH   = (type(fnt) == "table" and fnt.size or 12)
    -- Measure with the font itself (native pixel width) instead of guessing
    -- from byte count, so wrapping is correct for multibyte text.
    local measure = core.fontMeasure(fnt, lineH * 0.6)

    for i, line in ipairs(core.wrapText(text, wrapWidth, measure)) do
        local ox = core.alignOffset(align, measure(line), wrapWidth)
        love.graphics.print(line, x + ox, y + (i - 1) * lineH * 1.2)
    end
end
