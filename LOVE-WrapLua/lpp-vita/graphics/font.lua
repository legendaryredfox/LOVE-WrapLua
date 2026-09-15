-- lpp-vita graphics: Font objects.

function love.graphics.newFont(setfont, setsize)
    if tonumber(setfont) then setsize = setfont; setfont = nil end
    setsize = setsize or 12

    local fobj
    if setfont then
        fobj = Font.load(lv1lua.dataloc .. "game/" .. setfont)
    else
        fobj = lv1lua.gfx.defaultFont
    end
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        setsize = setsize * 0.825
    end
    Font.setPixelSizes(fobj, setsize)

    local wrap = { _font = fobj, size = setsize }
    function wrap:getWidth(text)
        if not text or text == "" then return 0 end
        -- Native Font.getTextWidth(font, text) returns the real pixel width,
        -- so multibyte glyphs measure correctly. Fall back to an estimate only
        -- if the binding is missing.
        if Font.getTextWidth then return Font.getTextWidth(self._font, text) end
        return #text * self.size * 0.6
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
    local f = lv1lua.current.font
    if not f then return end
    if setsize then f.size = setsize end
    -- Push the *final* size to the native font, so getTextWidth measures at
    -- the size we actually print with.
    if f._font then Font.setPixelSizes(f._font, f.size) end
end

function love.graphics.getFont() return lv1lua.current.font end

function love.graphics.setNewFont(setfont, setsize)
    local newfont = love.graphics.newFont(setfont, setsize)
    love.graphics.setFont(newfont, setsize)
    return newfont
end

-- LÖVE ships a usable 12px default font; print/printf and getFont():getWidth
-- must work before the game calls setFont.
lv1lua.current.font = love.graphics.newFont(nil, 12)
