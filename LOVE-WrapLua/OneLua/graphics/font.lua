-- OneLua graphics: Font objects and the font cache.

local defaultFontPath = lv1lua.gfx.defaultFontPath

-- OneLua's screen.textheight is broken (it ignores the font); report the
-- requested pixel size instead.
function screen.textheight(font, size) return size end

font.setdefault(font.load(defaultFontPath))

-- Fonts are cached by name+size: loading the same face twice on a PSP costs
-- both time and scarce memory.
local cache = { instances = {} }
function cache:key(name, size)      return name .. size end
function cache:get(name, size)      return self.instances[self:key(name, size)] end
function cache:put(name, instance)  self.instances[self:key(name, instance.size)] = instance end
lv1lua.gfx.fonts = cache

function love.graphics.newFont(setfont, setsize)
    -- newFont(size) and newFont() both mean "default face".
    if not setfont or tonumber(setfont) then
        setsize = tonumber(setfont) or setsize or 12
        setfont = defaultFontPath
    end
    setsize = setsize or 12

    local cached = cache:get(setfont, setsize)
    if cached then return cached end

    -- `guineaPig` is a second handle used only for measuring, so measuring at
    -- one size never disturbs the handle we print with.
    local loaded, guinea
    if setfont == defaultFontPath then
        loaded = font.load(defaultFontPath)
        guinea = font.load(defaultFontPath)
    else
        loaded = font.load(lv1lua.dataloc .. "game/" .. setfont)
        guinea = font.load(lv1lua.dataloc .. "game/" .. setfont)
    end

    local nFont = { name=setfont, font=loaded, guineaPig=guinea, size=setsize }
    function nFont:getWidth(text)
        if not text or text == "" then return 0 end
        return screen.textwidth(self.guineaPig, text, self.size / lv1lua.gfx.fontUnit)
    end
    function nFont:getHeight() return screen.textheight(self.guineaPig, self.size) end
    function nFont:getBaseline() return self.size end
    function nFont:getAscent()   return self.size end
    function nFont:getDescent()  return 0 end
    function nFont:getLineHeight()  return 1.2 end
    function nFont:setLineHeight(h) end
    function nFont:hasGlyph(codepoint) return true end
    function nFont:getKerning(l,r) return 0 end
    function nFont:setFallbacks(...) end
    function nFont:getDPIScale() return 1 end
    function nFont:getFilter() return "linear","linear",1 end
    function nFont:setFilter() end

    cache:put(setfont, nFont)
    return nFont
end

function love.graphics.setFont(setfont, setsize)
    lv1lua.current.font = setfont
    if setsize then lv1lua.current.font.size = setsize end
end

function love.graphics.getFont()
    return lv1lua.current.font
end

function love.graphics.setNewFont(setfont, setsize)
    local newfont = love.graphics.newFont(setfont, setsize)
    love.graphics.setFont(newfont, setsize)
    return newfont
end

-- LÖVE starts with a usable 12px default font, so print/printf work before the
-- game calls setFont.
lv1lua.current.font = love.graphics.newFont(defaultFontPath, 12)
