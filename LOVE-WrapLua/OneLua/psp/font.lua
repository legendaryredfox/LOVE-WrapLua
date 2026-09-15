-- PSP graphics: Font objects.
--
-- Custom faces are not loadable on PSP (the PGF system font is the only one),
-- so every Font wrapper points at that handle and only the size varies.

function love.graphics.newFont(setfont, setsize)
    if tonumber(setfont) then setsize = setfont; setfont = nil end
    setsize = setsize or 12
    local fontDef = { font = lv1lua.gfx.defaultFont.font, size = setsize }
    function fontDef:getWidth(t)
        if not t or t == "" then return 0 end
        return screen.textwidth(self.font, t, self.size / lv1lua.gfx.fontUnit)
    end
    function fontDef:getHeight()     return self.size end
    function fontDef:getBaseline()   return self.size end
    function fontDef:getAscent()     return self.size end
    function fontDef:getDescent()    return 0 end
    function fontDef:getLineHeight() return 1.2 end
    function fontDef:setLineHeight() end
    return fontDef
end

function love.graphics.setFont(setfont, setsize)
    -- Every Font on PSP wraps the same PGF system face, so a requested face
    -- changes nothing but its object still carries the measuring methods.
    lv1lua.current.font = setfont or love.graphics.newFont(nil, 15)
    if setsize then lv1lua.current.font.size = setsize end
end

function love.graphics.getFont() return lv1lua.current.font end

function love.graphics.setNewFont(setfont, setsize)
    local newfont = love.graphics.newFont(setfont, setsize)
    love.graphics.setFont(newfont, setsize)
    return newfont
end

-- The PSP default is 15px (the PGF face's natural size), and print/printf must
-- work before the game calls setFont.
lv1lua.current.font = love.graphics.newFont(nil, 15)
