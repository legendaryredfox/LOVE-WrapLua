-- Shared printf: wrap, align and line spacing over each backend's print.
--
-- Only `love.graphics.print` is genuinely native (it has to reach
-- screen.print / Font.print / DrawText and apply that platform's scale), so it
-- stays in the backend. Wrapping, alignment and LOVE's line spacing
-- (getHeight() * getLineHeight()) are the same everywhere.

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
    text = type(text) == "table" and core.plainText(text) or tostring(text)
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

-- Coloured text goes through the backend's print one segment at a time; a segment's colour multiplies
-- the current colour, as LÖVE's does. A segment that holds a newline is not laid out as several lines.
function core.printColoured(nativePrint, text, x, y)
    x, y = x or 0, y or 0
    local fnt = lv1lua.current.font
    local br, bg, bb, ba = love.graphics.getColor()
    local r, g, b, a = br, bg, bb, ba
    for i = 1, #text do
        local seg = text[i]
        if type(seg) == "table" then
            r, g, b, a = br * (seg[1] or 1), bg * (seg[2] or 1), bb * (seg[3] or 1), ba * (seg[4] or 1)
        else
            seg = tostring(seg)
            if seg ~= "" then
                love.graphics.setColor(r, g, b, a)
                nativePrint(seg, x, y)
                x = x + fnt:getWidth(seg)
            end
        end
    end
    love.graphics.setColor(br, bg, bb, ba)
end

local nativePrint = love.graphics.print
function love.graphics.print(text, x, y)
    if type(text) == "table" then return core.printColoured(nativePrint, text, x, y) end
    return nativePrint(text, x, y)
end
