-- Shared printf: wrap, align and line spacing over each backend's print
-- (FIX_PLAN T5.1, text slice).
--
-- Only `love.graphics.print` is genuinely native (it has to reach
-- screen.print / Font.print / DrawText and apply that platform's scale), so it
-- stays in the backend. Everything above it was four copies that disagreed:
-- line spacing was a hardcoded 16 on PSP, 14 on PS3, size*1.2 on lpp-vita and
-- getHeight() on OneLua, and OneLua re-implemented word wrapping by hand
-- instead of using core/textwrap.lua. Spacing is now LOVE's
-- getHeight() * getLineHeight() everywhere.

local core = lv1lua.core

-- printf re-lays out the same strings every frame, which is expensive on a PSP.
-- The wrap result is cached per font+size+width+string; the cache is dropped
-- whole once it grows past the limit, which is cheaper than tracking ages and
-- bounded either way.
local wrapCache = { lines = {}, count = 0, limit = 128 }

function wrapCache:key(fnt, text, wrapWidth)
    local size = (type(fnt) == "table" and fnt.size) or 0
    return tostring(fnt) .. "\1" .. tostring(size) .. "\1"
           .. tostring(wrapWidth) .. "\1" .. text
end

function wrapCache:get(fnt, text, wrapWidth, measure)
    local key = self:key(fnt, text, wrapWidth)
    local hit = self.lines[key]
    if hit then return hit end
    if self.count >= self.limit then
        self.lines, self.count = {}, 0
    end
    local lines = core.wrapText(text, wrapWidth, measure)
    self.lines[key] = lines
    self.count = self.count + 1
    return lines
end

function wrapCache:clear() self.lines, self.count = {}, 0 end
lv1lua.gfx.wrapCache = wrapCache

-- Vertical advance between two printf lines, as LOVE computes it.
function core.lineHeight(fnt)
    if type(fnt) ~= "table" or not fnt.getHeight then return 12 * 1.2 end
    local mult = fnt.getLineHeight and fnt:getLineHeight() or 1
    return fnt:getHeight() * (mult or 1)
end

function love.graphics.printf(text, x, y, wrapWidth, align)
    if not text or text == "" then return end
    text = tostring(text)
    x, y = x or 0, y or 0
    align = align or "left"
    wrapWidth = wrapWidth or lv1lua.screenWidth

    local fnt     = lv1lua.current.font
    local size    = (type(fnt) == "table" and fnt.size) or 12
    local measure = core.fontMeasure(fnt, size * 0.6)
    local lines   = wrapCache:get(fnt, text, wrapWidth, measure)
    local lineH   = core.lineHeight(fnt)

    for i = 1, #lines do
        local ox = core.alignOffset(align, measure(lines[i]), wrapWidth)
        love.graphics.print(lines[i], x + ox, y + (i - 1) * lineH)
    end
end
