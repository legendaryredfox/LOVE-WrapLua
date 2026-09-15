-- OneLua graphics: print and printf.

local util  = lv1lua.util
local stack = lv1lua.gfx.transform

-- printf re-lays out the same strings every frame, which is expensive on a PSP.
-- Cache the laid-out lines per (text, align) and replay them while the font is
-- unchanged; entries not replayed for `purgeAt` frames are dropped.
local cachedPrintf = { text = {}, purgeAt = 100 }

function cachedPrintf:cache(text, line, x, y, align)
    local key = text .. align
    if not self.text[key] then
        self.text[key] = {lines={}, x={}, y={}, sizes={}, len=0, purgeCount=0}
    end
    local c = self.text[key]
    c.len = c.len + 1
    c.x[c.len], c.y[c.len], c.lines[c.len] = x, y, line
    c.font, c.size = lv1lua.current.font.font, lv1lua.current.font.size
end

function cachedPrintf:purge()
    for k, v in pairs(self.text) do
        v.purgeCount = v.purgeCount + 1
        if v.purgeCount >= self.purgeAt then self.text[k] = nil end
    end
end

function cachedPrintf:print(text, align)
    local key = text .. align
    local v = self.text[key]
    if not v then return false end
    if v.size ~= lv1lua.current.font.size or v.font ~= lv1lua.current.font.font then
        self.text[key] = nil; return false
    end
    v.purgeCount = 0
    for i = 1, v.len do love.graphics.print(v.lines[i], v.x[i], v.y[i]) end
    return true
end

-- ── print ────────────────────────────────────────────────────────
function love.graphics._defaultPrint(text, x, y, fontsize)
    x, y = x or 0, y or 0
    fontsize = fontsize or (lv1lua.current.font.size / lv1lua.gfx.fontUnit)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s; fontsize = fontsize * s
    end
    screen.print(lv1lua.current.font.font, x, y, text, fontsize, lv1lua.current.color)
end

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    stack:updateTransform()
    local t          = stack.transform
    local fontScale  = (t._scaleX + t._scaleY) / 2
    local fontsize   = lv1lua.current.font.size / lv1lua.gfx.fontUnit * fontScale
    local heightOff  = lv1lua.current.font:getHeight() * fontScale
    x = (x or 0) * t._scaleX
    y = (y or 0) * t._scaleY
    -- screen.print anchors on the native baseline; pull it up to LÖVE's top-left.
    y = y - (lv1lua.gfx.fontUnit - heightOff)
    love.graphics._defaultPrint(text, x, y, fontsize)
end

-- ── printf ───────────────────────────────────────────────────────
local function _getAlignX(x, align, size, wrapSize)
    return x + lv1lua.core.alignOffset(align, size, wrapSize)
end

local function _formatTextPrint(text, x, y, wrapWidth, align)
    local word, phrase = "", ""
    local wordW, phraseW = 0, 0
    local spaceW = lv1lua.current.font:getWidth(" ")
    local idx = 1

    -- Walk whole UTF-8 glyphs: measuring a multibyte character byte by byte
    -- would over-count its width several times over.
    for c in util.glyphs(text) do
        if c == "\n" or wordW > wrapWidth or wordW + phraseW > wrapWidth then
            if wordW > wrapWidth then
                cachedPrintf:cache(text, word, _getAlignX(x, align, wordW, wrapWidth), y, align)
                love.graphics.print(word, _getAlignX(x, align, wordW, wrapWidth), y)
                word, wordW = "", 0
            elseif wordW + phraseW > wrapWidth then
                local found = false
                for i = idx, #text do
                    if text:sub(i,i) == " " then
                        cachedPrintf:cache(text, phrase, _getAlignX(x, align, phraseW+spaceW*2, wrapWidth), y, align)
                        love.graphics.print(phrase, _getAlignX(x, align, phraseW+spaceW*2, wrapWidth), y)
                        found = true
                        word, wordW = word..c, wordW + spaceW
                        break
                    end
                end
                if not found then
                    local combined = phrase..word
                    cachedPrintf:cache(text, combined, _getAlignX(x, align, phraseW+wordW+spaceW, wrapWidth), y, align)
                    love.graphics.print(combined, _getAlignX(x, align, phraseW+wordW+spaceW, wrapWidth), y)
                    word, wordW = "", 0
                end
            else
                local combined = phrase..word
                cachedPrintf:cache(text, combined, _getAlignX(x, align, wordW+phraseW, wrapWidth), y, align)
                love.graphics.print(combined, _getAlignX(x, align, wordW+phraseW, wrapWidth), y)
                word, wordW = "", 0
            end
            y = y + lv1lua.current.font:getHeight()
            phrase, phraseW = "", 0
        elseif c == " " then
            if phrase ~= "" then
                phrase, phraseW = phrase.." "..word, wordW + phraseW + spaceW
            else
                phrase, phraseW = word, wordW
            end
            word, wordW = "", 0
        else
            word  = word..c
            wordW = wordW + lv1lua.current.font:getWidth(c)
        end
        idx = idx + #c
    end

    if phraseW ~= 0 or wordW ~= 0 then
        -- Only join with a space when there is actually a phrase to join to,
        -- otherwise a single-word line gets a leading space (and is measured
        -- as if it had two).
        local combined, combinedW
        if phrase ~= "" then
            combined, combinedW = phrase.." "..word, phraseW + wordW + spaceW
        else
            combined, combinedW = word, wordW
        end
        local ax = _getAlignX(x, align, combinedW, wrapWidth)
        cachedPrintf:cache(text, combined, ax, y, align)
        love.graphics.print(combined, ax, y)
    end
end

function love.graphics.printf(text, x, y, wrapWidth, align)
    if not text or text == "" then return end
    align = align or "left"
    cachedPrintf:purge()
    if cachedPrintf:print(text, align) then return end
    _formatTextPrint(text, x, y, wrapWidth, align)
end
