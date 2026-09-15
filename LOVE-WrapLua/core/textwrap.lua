-- Greedy word wrapping, shared by the backends' printf.
--
-- Width always comes from the caller's `measure(string)` callback, which is
-- backed by the native text-measuring call where the platform has one. Nothing
-- here assumes a fixed character width.

lv1lua.core = lv1lua.core or {}

-- Splits `text` into lines no wider than `wrapWidth`. Explicit newlines are
-- honoured (LÖVE breaks on them regardless of the wrap limit), and a single
-- word wider than the limit gets its own line instead of being dropped.
function lv1lua.core.wrapText(text, wrapWidth, measure)
    local lines = {}
    for paragraph in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        local cur = ""
        for word in paragraph:gmatch("%S+") do
            local candidate = cur == "" and word or (cur .. " " .. word)
            if cur ~= "" and measure(candidate) > wrapWidth then
                lines[#lines + 1] = cur
                cur = word
            else
                cur = candidate
            end
        end
        lines[#lines + 1] = cur
    end
    return lines
end

-- Horizontal offset for one line inside the wrap box.
function lv1lua.core.alignOffset(align, lineWidth, wrapWidth)
    if align == "center" then return (wrapWidth - lineWidth) / 2 end
    if align == "right"  then return wrapWidth - lineWidth end
    return 0
end

-- Builds the measure callback for a font wrapper, falling back to a glyph-count
-- estimate when the platform exposes no real metrics.
function lv1lua.core.fontMeasure(fnt, fallbackGlyphWidth)
    if type(fnt) == "table" and fnt.getWidth then
        return function(s) return fnt:getWidth(s) end
    end
    local w = fallbackGlyphWidth or 8
    return function(s) return lv1lua.util.glyphCount(s) * w end
end
