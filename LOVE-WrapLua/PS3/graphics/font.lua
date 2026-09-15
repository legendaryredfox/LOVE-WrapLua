-- PS3 graphics: Font objects.
--
-- No PS3 Lua player exposes a text-measuring call, so width is an estimate.
-- It counts UTF-8 glyphs rather than bytes, so multibyte text is not
-- over-measured by 2-4x. Documented in Implemented.md.

local util = lv1lua.util

function love.graphics.newFont(setfont, setsize)
    if tonumber(setfont) then setsize = setfont; setfont = nil end
    setsize = setsize or 12
    local wrap = { _font = nil, size = setsize }
    function wrap:getWidth(t)
        if not t or t == "" then return 0 end
        return util.glyphCount(t) * self.size * 0.6
    end
    function wrap:getHeight()     return self.size end
    function wrap:getBaseline()   return self.size end
    function wrap:getAscent()     return self.size end
    function wrap:getDescent()    return 0 end
    function wrap:getLineHeight() return 1.2 end
    function wrap:setLineHeight() end
    return wrap
end

function love.graphics.setFont(setfont, setsize)
    if setfont then lv1lua.current.font = setfont end
    if setsize and lv1lua.current.font then lv1lua.current.font.size = setsize end
end

function love.graphics.getFont() return lv1lua.current.font end

function love.graphics.setNewFont(setfont, setsize)
    local newfont = love.graphics.newFont(setfont, setsize)
    love.graphics.setFont(newfont, setsize)
    return newfont
end

-- LÖVE ships a usable 12px default font; print/printf must work before setFont.
lv1lua.current.font = love.graphics.newFont(nil, 12)
