local defaultfont        = lv1lua.dataloc.."LOVE-WrapLua/Vera.ttf"
local scale              = 0.75
local defaultMinFilter   = 3
local defaultMagFilter   = 3
local defaultAnisotropy  = 0
local _lineWidth         = 1

local _loadedFonts = { fontInstances = {} }
function _loadedFonts:hasLoaded(name, size) return self.fontInstances[name..size] ~= nil end
function _loadedFonts:setLoaded(name, inst) self.fontInstances[name..inst.size] = inst end

-- OneLua's screen.textheight is broken; override to just return size.
local __oldScreenTxtHeight = screen.textheight
function screen.textheight(font, size) return size end

local _VITA_DEFAULT_PRINT_Y_OFFSET = 18.5

-- ──────────────────────────────────────────────────────────────
-- Transform stack
-- ──────────────────────────────────────────────────────────────
local Transform = {}
Transform.__index = Transform

function Transform:new()
    return setmetatable({
        _offsetX=0, _offsetY=0,
        _scaleX=1,  _scaleY=1,
        _rotation=0,
        _usingScissor=false,
        _scissorX=0, _scissorY=0,
        _scissorWidth=0, _scissorHeight=0,
    }, Transform)
end

local _transformStack = {
    transform = Transform:new(),
    stack     = {},
    _dirty    = true,
    updateTransform = function(self)
        if not self._dirty then return end
        local x, y, sx, sy, rot = 0, 0, 1, 1, 0
        local usingScissor, sx_, sy_, sw, sh = false, 0, 0, 0, 0
        for i = 1, #self.stack do
            local t = self.stack[i]
            x   = x * t._scaleX + t._offsetX
            y   = y * t._scaleY + t._offsetY
            sx  = sx * t._scaleX
            sy  = sy * t._scaleY
            rot = rot + t._rotation
            if t._usingScissor then
                usingScissor = true
                sx_, sy_, sw, sh = t._scissorX, t._scissorY, t._scissorWidth, t._scissorHeight
            end
        end
        local tr = self.transform
        tr._offsetX, tr._offsetY = x, y
        tr._scaleX,  tr._scaleY  = sx, sy
        tr._rotation             = rot
        tr._usingScissor         = usingScissor
        tr._scissorX, tr._scissorY, tr._scissorWidth, tr._scissorHeight = sx_, sy_, sw, sh
        self._dirty = false
    end
}

-- ──────────────────────────────────────────────────────────────
-- Cached printf (unchanged from before)
-- ──────────────────────────────────────────────────────────────
local cachedPrintf = { text = {}, purgeAt = 100 }
function cachedPrintf:cache(text, line, x, y, align)
    local key = text..align
    if not self.text[key] then
        self.text[key] = {lines={},x={},y={},sizes={},len=0,purgeCount=0}
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
    local key = text..align
    local v = self.text[key]
    if not v then return false end
    if v.size ~= lv1lua.current.font.size or v.font ~= lv1lua.current.font.font then
        self.text[key] = nil; return false
    end
    v.purgeCount = 0
    for i = 1, v.len do love.graphics.print(v.lines[i], v.x[i], v.y[i]) end
    return true
end

-- ──────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────
function __mathRound(value)
    local remain = value % 1
    if remain >= 0.5 then return value + 1 - remain end
    return value - remain
end

local function _c255(r,g,b,a)     -- LÖVE 0-1 → platform 0-255
    return math.floor(r*255+0.5),
           math.floor(g*255+0.5),
           math.floor(b*255+0.5),
           math.floor((a or 1)*255+0.5)
end

-- Compatibility: old OneLua API wraps
local _oldImageGetW = image.getw
local _oldImageGetH = image.geth
function image.getw(img)
    if img and img.imgData then return image.getrealw(img.imgData) end
    return _oldImageGetW(img)
end
function image.geth(img)
    if img and img.imgData then return image.getrealh(img.imgData) end
    return _oldImageGetH(img)
end

-- ──────────────────────────────────────────────────────────────
-- Initial state
-- ──────────────────────────────────────────────────────────────
font.setdefault(font.load(defaultfont))
lv1lua.current = {
    font       = defaultfont,
    color      = color.new(255,255,255,255),
    colorRGBA  = {1,1,1,1},
    bgcolor    = color.new(0,0,0,255),
    bgColorRGBA= {0,0,0,1},
    canvas     = nil,
}

-- ──────────────────────────────────────────────────────────────
-- Image
-- ──────────────────────────────────────────────────────────────
function love.graphics.newImage(filename, settings)
    local img = image.load(lv1lua.dataloc.."game/"..filename)
    if lv1luaconf.imgscale == true then
        image.scale(img, scale*100)
    end
    local w = setmetatable({
        imgData = img,
        flipX   = false,
        flipY   = false,
        getWidth      = function(self) return image.getw(self) end,
        getHeight     = function(self) return image.geth(self) end,
        getDimensions = function(self) return image.getw(self), image.geth(self) end,
        getFilter     = function(self) return "linear","linear",1 end,
        setFilter     = function(self) end,
        getWrap       = function(self) return "clamp","clamp" end,
        setWrap       = function(self) end,
        getMipmapFilter= function(self) return nil, 0 end,
        setMipmapFilter= function(self) end,
        isCompressed  = function(self) return false end,
        getFormat     = function(self) return "rgba8" end,
        getPixelDimensions = function(self) return image.getw(self), image.geth(self) end,
        getDPIScale   = function(self) return 1 end,
    }, {})
    function w:__handleNegativeScale(x, y, sx, sy)
        if sx > 0 and self.flipX then
            image.fliph(self.imgData); self.flipX = not self.flipX
        elseif sx < 0 and not self.flipX then
            image.fliph(self.imgData); self.flipX = not self.flipX
        end
        if sy > 0 and self.flipY then
            image.flipv(self.imgData); self.flipY = not self.flipY
        elseif sy < 0 and not self.flipY then
            image.flipv(self.imgData); self.flipY = not self.flipY
        end
        if sx < 0 then x = x + self:getWidth()  * sx end
        if sy < 0 then y = y + self:getHeight() * sy end
        return x, y
    end
    return w
end

-- ──────────────────────────────────────────────────────────────
-- Quad
-- ──────────────────────────────────────────────────────────────
function love.graphics.newQuad(x, y, width, height, swOrImg, sh)
    -- accept (x,y,w,h, image) or (x,y,w,h, sw,sh)
    local sw, _sh
    if type(swOrImg) == "table" then
        sw, _sh = swOrImg:getDimensions()
    else
        sw, _sh = swOrImg, sh
    end
    local q = {
        x=x, y=y, width=width, height=height, sw=sw, sh=_sh,
        _savedScaleX=1, _savedScaleY=1, _bufferImage=nil,
        getTextureDimensions = function(self) return self.sw, self.sh end,
        getViewport   = function(self) return self.x, self.y, self.width, self.height end,
        setViewport   = function(self,x,y,w,h,sw,sh)
            self.x,self.y,self.width,self.height = x,y,w,h
            if sw then self.sw=sw; self.sh=sh end
        end,
    }
    function q:getViewportScaled(sx, sy) return self.x*sx, self.y*sy, self.width*sx, self.height*sy end
    function q:getTextureDimensionsScaled(sx,sy) return self.sw*sx, self.sh*sy end
    function q:updateBufferScaled(drawable, sx, sy)
        if sx ~= self._savedScaleX or sy ~= self._savedScaleY or not self._bufferImage then
            if self._bufferImage then image.lost(drawable) end
            self._bufferImage = image.copyscale(drawable, self:getTextureDimensionsScaled(sx,sy))
            self._savedScaleX, self._savedScaleY = sx, sy
        end
    end
    function q:draw(drawable, x, y, r, sx, sy)
        self:updateBufferScaled(drawable, sx, sy)
        love.graphics._defaultDraw(self._bufferImage, x, y, r, sx, sy, self:getViewportScaled(sx,sy))
    end
    return q
end

-- ──────────────────────────────────────────────────────────────
-- Transform stack operations
-- ──────────────────────────────────────────────────────────────
function love.graphics.push(stack)
    _transformStack.stack[#_transformStack.stack + 1] = Transform:new()
    _transformStack._dirty = true
end
love.graphics.push()

function love.graphics.pop()
    if #_transformStack.stack > 0 then
        _transformStack.stack[#_transformStack.stack] = nil
        _transformStack._dirty = true
    end
end

function love.graphics.translate(offsetX, offsetY)
    local top = _transformStack.stack[#_transformStack.stack]
    if top then top._offsetX = offsetX; top._offsetY = offsetY; _transformStack._dirty = true end
end

function love.graphics.scale(sx, sy)
    if not sy then sy = sx end
    local top = _transformStack.stack[#_transformStack.stack]
    if top then top._scaleX = sx; top._scaleY = sy; _transformStack._dirty = true end
end

function love.graphics.rotate(angle)
    local top = _transformStack.stack[#_transformStack.stack]
    if top then top._rotation = (top._rotation or 0) + angle; _transformStack._dirty = true end
end

function love.graphics.shear(kx, ky)
    -- approximation: treat shear as scale bias (no native shear in OneLua)
end

function love.graphics.origin()
    local top = _transformStack.stack[#_transformStack.stack]
    if top then
        top._offsetX, top._offsetY = 0, 0
        top._scaleX,  top._scaleY  = 1, 1
        top._rotation = 0
        _transformStack._dirty = true
    end
end

function love.graphics.reset()
    _transformStack.stack = {}
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBackgroundColor(0, 0, 0)
    _lineWidth = 1
end

function love.graphics.applyTransform(transform)
    if transform and transform._m then
        local m = transform._m
        love.graphics.translate(m[7], m[8])
        love.graphics.scale(m[1], m[5])
    end
end

function love.graphics.replaceTransform(transform)
    love.graphics.origin()
    love.graphics.applyTransform(transform)
end

function love.graphics.transformPoint(x, y)
    _transformStack:updateTransform()
    local t = _transformStack.transform
    return x * t._scaleX + t._offsetX, y * t._scaleY + t._offsetY
end

function love.graphics.inverseTransformPoint(x, y)
    _transformStack:updateTransform()
    local t = _transformStack.transform
    if t._scaleX == 0 or t._scaleY == 0 then return x, y end
    return (x - t._offsetX) / t._scaleX, (y - t._offsetY) / t._scaleY
end

function love.graphics.setScissor(x, y, w, h)
    local top = _transformStack.stack[#_transformStack.stack]
    if top then
        top._usingScissor = (x ~= nil)
        top._scissorX, top._scissorY, top._scissorWidth, top._scissorHeight = x, y, w, h
        _transformStack._dirty = true
    end
end

function love.graphics.getScissor()
    _transformStack:updateTransform()
    local t = _transformStack.transform
    if not t._usingScissor then return nil end
    return t._scissorX, t._scissorY, t._scissorWidth, t._scissorHeight
end

function love.graphics.intersectScissor(x, y, w, h)
    love.graphics.setScissor(x, y, w, h)
end

-- ──────────────────────────────────────────────────────────────
-- Filters
-- ──────────────────────────────────────────────────────────────
function love.graphics.setDefaultFilter(min, mag, anisotropy)
    if min == "linear"  then min = __IMG_FILTER_LINEAR
    elseif min == "nearest" or min == "point" then min = __IMG_FILTER_POINT end
    if mag == "linear"  then mag = __IMG_FILTER_LINEAR
    elseif mag == "nearest" or mag == "point" then mag = __IMG_FILTER_POINT end
    defaultMinFilter    = min
    defaultMagFilter    = mag
    defaultAnisotropy   = anisotropy and 1 or 0
end

function love.graphics.getDefaultFilter()
    return defaultMinFilter, defaultMagFilter, defaultAnisotropy
end

-- ──────────────────────────────────────────────────────────────
-- Color
-- ──────────────────────────────────────────────────────────────
function love.graphics.setColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    a = a or 1
    lv1lua.current.colorRGBA = {r, g, b, a}
    local r8,g8,b8,a8 = _c255(r, g, b, a)
    lv1lua.current.color = color.new(r8, g8, b8, a8)
end

function love.graphics.getColor()
    local c = lv1lua.current.colorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.setBackgroundColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    a = a or 1
    lv1lua.current.bgColorRGBA = {r, g, b, a}
    local r8,g8,b8,a8 = _c255(r, g, b, a)
    lv1lua.current.bgcolor = color.new(r8, g8, b8, a8)
end

function love.graphics.getBackgroundColor()
    local c = lv1lua.current.bgColorRGBA
    return c[1], c[2], c[3], c[4]
end

function love.graphics.clear(r, g, b, a)
    if r == nil then
        screen.clear(lv1lua.current.bgcolor)
    elseif type(r) == "table" then
        local r8,g8,b8,a8 = _c255(r[1], r[2], r[3], r[4] or 1)
        screen.clear(color.new(r8,g8,b8,a8))
    else
        local r8,g8,b8,a8 = _c255(r, g or 0, b or 0, a or 1)
        screen.clear(color.new(r8,g8,b8,a8))
    end
end

-- ──────────────────────────────────────────────────────────────
-- Blend mode (stub — OneLua has limited blend support)
-- ──────────────────────────────────────────────────────────────
lv1lua.current.blendMode = "alpha"

function love.graphics.setBlendMode(mode, alphamode)
    lv1lua.current.blendMode = mode
end

function love.graphics.getBlendMode()
    return lv1lua.current.blendMode, "alphamultiply"
end

-- ──────────────────────────────────────────────────────────────
-- Line width / style
-- ──────────────────────────────────────────────────────────────
function love.graphics.setLineWidth(w)  _lineWidth = w or 1 end
function love.graphics.getLineWidth()   return _lineWidth end
function love.graphics.setLineStyle(s)  end
function love.graphics.getLineStyle()   return "smooth" end
function love.graphics.setLineJoin(j)   end
function love.graphics.getLineJoin()    return "miter" end
function love.graphics.setPointSize(s)  end
function love.graphics.getPointSize()   return 1 end

-- ──────────────────────────────────────────────────────────────
-- Stencil (stub)
-- ──────────────────────────────────────────────────────────────
function love.graphics.stencil(fn, action, value, keepvalues) if fn then fn() end end
function love.graphics.setStencilTest(compare, value) end
function love.graphics.getStencilTest() return "always", 0 end

-- ──────────────────────────────────────────────────────────────
-- Canvas (stub — offscreen rendering not available on OneLua)
-- ──────────────────────────────────────────────────────────────
local _Canvas = {}
_Canvas.__index = _Canvas
function _Canvas:getWidth()  return self._width end
function _Canvas:getHeight() return self._height end
function _Canvas:getDimensions() return self._width, self._height end
function _Canvas:getFormat() return "rgba8" end
function _Canvas:getMSAA()   return 0 end
function _Canvas:getFilter() return "linear","linear",1 end
function _Canvas:setFilter() end
function _Canvas:getWrap()   return "clamp","clamp" end
function _Canvas:setWrap()   end
function _Canvas:newImageData() return nil end
function _Canvas:renderTo(fn)   if fn then fn() end end

function love.graphics.newCanvas(width, height, settings)
    return setmetatable({
        _width  = width  or lv1lua.screenWidth,
        _height = height or lv1lua.screenHeight,
        imgData = nil,
    }, _Canvas)
end

function love.graphics.setCanvas(canvas)
    lv1lua.current.canvas = canvas
end

function love.graphics.getCanvas()
    return lv1lua.current.canvas
end

-- ──────────────────────────────────────────────────────────────
-- Shader (stub)
-- ──────────────────────────────────────────────────────────────
local _Shader = {}
_Shader.__index = _Shader
function _Shader:send()     end
function _Shader:sendColor() end
function _Shader:hasUniform() return false end
function _Shader:getWarnings() return "" end

function love.graphics.newShader(code, pixelcode)
    return setmetatable({}, _Shader)
end

function love.graphics.setShader(shader)
    lv1lua.current.shader = shader
end

function love.graphics.getShader()
    return lv1lua.current.shader
end

-- ──────────────────────────────────────────────────────────────
-- Screen info
-- ──────────────────────────────────────────────────────────────
function love.graphics.getDimensions()
    return lv1lua.screenWidth, lv1lua.screenHeight
end

function love.graphics.getWidth()  return lv1lua.screenWidth  end
function love.graphics.getHeight() return lv1lua.screenHeight end

function love.graphics.getStats()
    return { drawcalls=0, canvasswitches=0, texturememory=0, images=0,
             canvases=0, fonts=0, shaderswitches=0, drawcallsbatched=0 }
end

function love.graphics.isActive()   return true  end
function love.graphics.isGammaCorrect() return false end

function love.graphics.getRendererInfo()
    return "OneLua","1.0","",""
end

function love.graphics.getSystemLimits()
    return { pointsize=1, texturesize=512, multicanvas=1, canvasmsaa=0 }
end

function love.graphics.getSupported()
    return { clampzero=false, lighten=false, multicanvasformats=false, glsl3=false, instancing=false }
end

function love.graphics.captureScreenshot(callback_or_filename)
    -- Not available on this platform
end

function love.graphics.present() end  -- handled by main loop

-- ──────────────────────────────────────────────────────────────
-- Draw pipeline
-- ──────────────────────────────────────────────────────────────
function love.graphics._defaultDraw(drawable, x, y, r, sx, sy, xf, yf, w, h)
    if drawable == nil then print("No drawable"); return end
    x = x or 0; y = y or 0
    if sx and not sy then sy = sx end

    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x = x * scale; y = y * scale
    end

    _transformStack:updateTransform()
    local rot = (r or 0) + _transformStack.transform._rotation
    if rot ~= 0 then
        image.rotate(drawable, (rot / math.pi) * 180)
    end

    if sx then
        image.setfilter(drawable, defaultMagFilter, defaultMinFilter)
        image.resize(drawable, image.getrealw(drawable)*sx, image.getrealh(drawable)*sy)
    end

    if xf ~= nil then
        image.blit(drawable, x, y, xf, yf, w, h, color.a(lv1lua.current.color))
    else
        image.blit(drawable, x, y, color.a(lv1lua.current.color))
    end
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy, kx, ky)
    -- Handle SpriteBatch and Text objects
    if type(drawable) == "table" and drawable._draw then
        drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
        return
    end

    local isNew = (type(drawable) == "table")
    _transformStack:updateTransform()
    local transform = _transformStack.transform
    local _x, _y, _r, _sx, _sy

    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        -- draw(drawable, quad, x, y, r, sx, sy, ox, oy)
        _x  = (y  == nil) and transform._offsetX or y  + transform._offsetX
        _y  = (r  == nil) and transform._offsetY or r  + transform._offsetY
        _r  = sx
        _sx = (sy == nil) and transform._scaleX  or sy * transform._scaleX
        _sy = (ox == nil) and transform._scaleY  or ox * transform._scaleY
        ox, oy = oy or 0, kx or 0
        local absSx, absSy = math.abs(_sx), math.abs(_sy)
        _x = __mathRound((_x - ox * absSx) * absSx)
        _y = __mathRound((_y - oy * absSy) * absSy)
        if isNew then
            _x, _y = drawable:__handleNegativeScale(_x, _y, _sx, _sy)
            xOrQuad:draw(drawable.imgData, _x, _y, _r, absSx, absSy)
        else
            xOrQuad:draw(drawable, _x, _y, _r, absSx, absSy)
        end
    else
        -- draw(drawable, x, y, r, sx, sy, ox, oy)
        _x  = (xOrQuad == nil) and 0 or xOrQuad
        _y  = y  or 0
        _sx = (sx == nil) and transform._scaleX or sx * transform._scaleX
        _sy = (sy == nil) and transform._scaleY or sy * transform._scaleY
        ox, oy = ox or 0, oy or 0
        local absSx, absSy = math.abs(_sx), math.abs(_sy)
        _x = __mathRound((_x - ox * absSx) + transform._offsetX * absSx)
        _y = __mathRound((_y - oy * absSy) + transform._offsetY * absSy)
        if isNew then
            _x, _y = drawable:__handleNegativeScale(_x, _y, _sx, _sy)
            love.graphics._defaultDraw(drawable.imgData, _x, _y, r, absSx, absSy)
        else
            love.graphics._defaultDraw(drawable, _x, _y, r, absSx, absSy)
        end
    end
end

-- ──────────────────────────────────────────────────────────────
-- Font
-- ──────────────────────────────────────────────────────────────
function love.graphics.newFont(setfont, setsize)
    if not setfont or tonumber(setfont) then
        setsize = tonumber(setfont) or setsize or 12
        setfont = defaultfont
    end
    setsize = setsize or 12
    local fontName = setfont

    if not _loadedFonts:hasLoaded(fontName, setsize) then
        local loaded, guinea
        if fontName == defaultfont then
            loaded  = font.load(defaultfont)
            guinea  = font.load(defaultfont)
        else
            loaded  = font.load(lv1lua.dataloc.."game/"..fontName)
            guinea  = font.load(lv1lua.dataloc.."game/"..fontName)
        end
        local nFont = { name=fontName, font=loaded, guineaPig=guinea, size=setsize }
        function nFont:getWidth(text)
            return screen.textwidth(self.guineaPig, text, self.size / 18.5)
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
        _loadedFonts:setLoaded(fontName, nFont)
        return nFont
    else
        return _loadedFonts.fontInstances[fontName..setsize]
    end
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

-- ──────────────────────────────────────────────────────────────
-- Print / printf
-- ──────────────────────────────────────────────────────────────
function love.graphics._defaultPrint(text, x, y, fontsize)
    x, y = x or 0, y or 0
    fontsize = fontsize or (lv1lua.current.font.size / 18.5)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x = x * scale; y = y * scale; fontsize = fontsize * scale
    end
    screen.print(lv1lua.current.font.font, x, y, text, fontsize, lv1lua.current.color)
end

function love.graphics.print(text, x, y)
    if not text or text == "" then return end
    _transformStack:updateTransform()
    local _fontScale = (_transformStack.transform._scaleX + _transformStack.transform._scaleY) / 2
    local fontsize   = lv1lua.current.font.size / 18.5 * _fontScale
    local heightOff  = lv1lua.current.font:getHeight() * _fontScale
    x = (x or 0) * _transformStack.transform._scaleX
    y = (y or 0) * _transformStack.transform._scaleY
    y = y - (_VITA_DEFAULT_PRINT_Y_OFFSET - heightOff)
    love.graphics._defaultPrint(text, x, y, fontsize)
end

local function _getAlignX(x, align, size, wrapSize)
    if align == "center" then return x + (wrapSize - size) / 2
    elseif align == "right" then return x + wrapSize - size
    else return x end
end

local function _formatTextPrint(text, x, y, wrapWidth, align)
    local word, phrase = "", ""
    local wordW, phraseW = 0, 0
    local spaceW = lv1lua.current.font:getWidth(" ")
    local idx = 1

    for c in string.gmatch(text, ".") do
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
        idx = idx + 1
    end

    if phraseW ~= 0 or wordW ~= 0 then
        local combined = phrase.." "..word
        cachedPrintf:cache(text, combined, _getAlignX(x, align, wordW+phraseW+spaceW*2, wrapWidth), y, align)
        love.graphics.print(combined, _getAlignX(x, align, wordW+phraseW+spaceW*2, wrapWidth), y)
    end
end

function love.graphics.printf(text, x, y, wrapWidth, align)
    if not text or text == "" then return end
    align = align or "left"
    cachedPrintf:purge()
    if cachedPrintf:print(text, align) then return end
    _formatTextPrint(text, x, y, wrapWidth, align)
end

-- ──────────────────────────────────────────────────────────────
-- Primitives
-- ──────────────────────────────────────────────────────────────
function love.graphics.rectangle(mode, x, y, w, h, rx, ry)
    _transformStack:updateTransform()
    local t = _transformStack.transform
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x=x*scale; y=y*scale; w=w*scale; h=h*scale
    end
    local W = w * t._scaleX
    local H = h * t._scaleY
    if mode == "fill" then
        draw.fillrect(x, y, W, H, lv1lua.current.color)
    elseif mode == "line" then
        draw.rect(x, y, W, H, lv1lua.current.color)
    end
end

function love.graphics.line(...)
    local coords
    if type(select(1,...)) == "table" then coords = select(1,...)
    else coords = {...} end
    for i = 1, #coords - 2, 2 do
        draw.line(coords[i], coords[i+1], coords[i+2], coords[i+3], lv1lua.current.color)
    end
end

function love.graphics.circle(mode, x, y, radius, segments)
    _transformStack:updateTransform()
    segments = segments or 32
    local r = radius * _transformStack.transform._scaleX
    if mode == "fill" then
        draw.circle(x, y, r, lv1lua.current.color, segments)
    else
        -- outline: approximate with line segments
        local pts = {}
        for i = 0, segments do
            local a = i / segments * math.pi * 2
            pts[#pts+1] = x + r * math.cos(a)
            pts[#pts+1] = y + r * math.sin(a)
        end
        love.graphics.polygon("line", pts)
    end
end

function love.graphics.ellipse(mode, x, y, rx, ry, segments)
    ry = ry or rx
    segments = segments or 32
    local pts = {}
    for i = 0, segments do
        local a = i / segments * math.pi * 2
        pts[#pts+1] = x + rx * math.cos(a)
        pts[#pts+1] = y + ry * math.sin(a)
    end
    love.graphics.polygon(mode, pts)
end

function love.graphics.polygon(mode, vertices, ...)
    local v = type(vertices) == "table" and vertices or {vertices, ...}
    if #v < 4 then return end
    if mode == "fill" then
        -- Fan triangulation from centroid (works for convex polygons)
        local cx, cy = 0, 0
        local n = #v / 2
        for i = 1, #v, 2 do cx = cx + v[i]; cy = cy + v[i+1] end
        cx, cy = cx / n, cy / n
        for i = 1, #v - 2, 2 do
            local x1,y1 = v[i],   v[i+1]
            local x2,y2 = v[i+2], v[i+3]
            -- draw as two triangles / lines (OneLua lacks fillpoly)
            draw.line(cx, cy, x1, y1, lv1lua.current.color)
            draw.line(x1, y1, x2, y2, lv1lua.current.color)
            draw.line(x2, y2, cx, cy, lv1lua.current.color)
        end
    else
        -- outline
        for i = 1, #v - 2, 2 do
            draw.line(v[i], v[i+1], v[i+2], v[i+3], lv1lua.current.color)
        end
        -- close
        draw.line(v[#v-1], v[#v], v[1], v[2], lv1lua.current.color)
    end
end

function love.graphics.arc(mode, arctype, x, y, radius, angle1, angle2, segments)
    -- handle old-style: arc(mode, x, y, radius, angle1, angle2, segments)
    if type(arctype) == "number" then
        segments = angle2; angle2 = angle1; angle1 = radius
        radius   = arctype; y = x; x = mode
        arctype  = "pie"; mode = "line"
    end
    arctype  = arctype  or "pie"
    segments = segments or 12
    local pts = {}
    if arctype == "pie" then
        pts[#pts+1] = x; pts[#pts+1] = y
    end
    for i = 0, segments do
        local a = angle1 + (angle2 - angle1) * i / segments
        pts[#pts+1] = x + radius * math.cos(a)
        pts[#pts+1] = y + radius * math.sin(a)
    end
    if arctype == "closed" then
        pts[#pts+1] = pts[1]; pts[#pts+1] = pts[2]
    end
    love.graphics.polygon(mode, pts)
end

function love.graphics.points(...)
    local coords
    if type(select(1,...)) == "table" then coords = select(1,...)
    else coords = {...} end
    for i = 1, #coords - 1, 2 do
        draw.fillrect(coords[i], coords[i+1], 1, 1, lv1lua.current.color)
    end
end

-- ──────────────────────────────────────────────────────────────
-- SpriteBatch
-- ──────────────────────────────────────────────────────────────
function love.graphics.newSpriteBatch(image, maxsprites, usage)
    local sb = {
        _image      = image,
        _maxsprites = maxsprites or 1000,
        _sprites    = {},
        _color      = nil,
    }
    function sb:add(quad_or_x, x, y, r, sx, sy, ox, oy, kx, ky)
        local entry
        if type(quad_or_x) == "table" and quad_or_x.getViewport then
            entry = {quad=quad_or_x, x=x, y=y, r=r, sx=sx, sy=sy, ox=ox, oy=oy}
        else
            entry = {x=quad_or_x, y=x, r=y, sx=r, sy=sx, ox=sy, oy=ox}
        end
        table.insert(self._sprites, entry)
        return #self._sprites
    end
    function sb:set(id, quad_or_x, x, y, r, sx, sy, ox, oy, kx, ky)
        local e = self._sprites[id]
        if not e then return end
        if type(quad_or_x) == "table" and quad_or_x.getViewport then
            e.quad,e.x,e.y,e.r,e.sx,e.sy,e.ox,e.oy = quad_or_x,x,y,r,sx,sy,ox,oy
        else
            e.x,e.y,e.r,e.sx,e.sy,e.ox,e.oy = quad_or_x,x,y,r,sx,sy,ox
        end
    end
    function sb:clear()    self._sprites = {} end
    function sb:flush()    end
    function sb:getImage() return self._image end
    function sb:getCount() return #self._sprites end
    function sb:setColor(r,g,b,a) self._color={r,g,b,a} end
    function sb:getColor() return self._color and unpack(self._color) end
    function sb:attachAttribute() end
    function sb:_draw(bx, by, br, bsx, bsy)
        for _, s in ipairs(self._sprites) do
            local dx = (s.x or 0) + (bx or 0)
            local dy = (s.y or 0) + (by or 0)
            if s.quad then
                love.graphics.draw(self._image, s.quad, dx, dy, s.r, s.sx, s.sy, s.ox, s.oy)
            else
                love.graphics.draw(self._image, dx, dy, s.r, s.sx, s.sy, s.ox, s.oy)
            end
        end
    end
    return sb
end

-- ──────────────────────────────────────────────────────────────
-- Text / TextBatch object
-- ──────────────────────────────────────────────────────────────
local _Text = {}
_Text.__index = _Text

function love.graphics.newText(fnt, text)
    local t = setmetatable({
        _font    = fnt or lv1lua.current.font,
        _batches = {},
        _width   = 0,
        _height  = 0,
    }, _Text)
    if text then t:set(text) end
    return t
end

love.graphics.newTextBatch = love.graphics.newText

function _Text:set(text)
    self._batches = {}
    if text then
        table.insert(self._batches, {text=text, x=0, y=0})
        self._width  = self._font:getWidth(text)
        self._height = self._font:getHeight()
    end
end

function _Text:add(text, x, y, angle, sx, sy, ox, oy)
    table.insert(self._batches, {text=text, x=x or 0, y=y or 0})
    self._width  = math.max(self._width,  (self._font:getWidth(text) or 0) + (x or 0))
    self._height = math.max(self._height, (self._font:getHeight()    or 0) + (y or 0))
    return #self._batches
end

function _Text:addf(text, wraplimit, align, x, y)
    table.insert(self._batches, {text=text, x=x or 0, y=y or 0, wrap=wraplimit, align=align})
    return #self._batches
end

function _Text:clear()
    self._batches = {}; self._width = 0; self._height = 0
end

function _Text:getFont()       return self._font end
function _Text:getWidth()      return self._width end
function _Text:getHeight()     return self._height end
function _Text:getDimensions() return self._width, self._height end

function _Text:_draw(x, y, r, sx, sy)
    local prev = lv1lua.current.font
    love.graphics.setFont(self._font)
    for _, b in ipairs(self._batches) do
        local dx, dy = (x or 0) + b.x, (y or 0) + b.y
        if b.wrap then
            love.graphics.printf(b.text, dx, dy, b.wrap, b.align)
        else
            love.graphics.print(b.text, dx, dy)
        end
    end
    love.graphics.setFont(prev)
end

-- ──────────────────────────────────────────────────────────────
-- Mesh (stub — not feasible without GPU access)
-- ──────────────────────────────────────────────────────────────
function love.graphics.newMesh(vertices, mode, usage)
    local mesh = { _verts=vertices, _mode=mode, _tex=nil }
    function mesh:setTexture(t) self._tex=t end
    function mesh:getTexture()  return self._tex end
    function mesh:setVertex(i,...) end
    function mesh:getVertex(i) return 0,0,0,0,1,1,1,1 end
    function mesh:getVertexCount() return type(self._verts)=="number" and self._verts or #(self._verts or {}) end
    function mesh:setDrawMode(m) self._mode=m end
    function mesh:getDrawMode()  return self._mode or "fan" end
    function mesh:setDrawRange(min,max) end
    function mesh:getDrawRange()  return 1, self:getVertexCount() end
    function mesh:attachAttribute() end
    function mesh:detachAttribute() end
    function mesh:flush() end
    function mesh:_draw(x,y,r,sx,sy) end
    return mesh
end

-- ──────────────────────────────────────────────────────────────
-- ParticleSystem (minimal - update/draw basics)
-- ──────────────────────────────────────────────────────────────
function love.graphics.newParticleSystem(image, buffer)
    local ps = {
        _image=image, _buffer=buffer or 1000,
        _particles={}, _emitting=false,
        _rate=1, _lifetime=1, _timer=0,
        _sx=0,_sy=0, _ex=0,_ey=0,
        _minspeed=0,_maxspeed=100,
        _minlife=1, _maxlife=2,
    }
    function ps:setEmissionRate(r)    self._rate=r end
    function ps:setParticleLifetime(a,b) self._minlife=a; self._maxlife=b or a end
    function ps:setLinearAcceleration(x1,y1,x2,y2) self._sx=x1;self._sy=y1;self._ex=x2;self._ey=y2 end
    function ps:setSpeed(min,max) self._minspeed=min; self._maxspeed=max or min end
    function ps:setSizeVariation(v)  end
    function ps:setSizes(...)        end
    function ps:setColors(...)       end
    function ps:setDirection(d)      self._dir=d end
    function ps:setSpread(s)         self._spread=s end
    function ps:setPosition(x,y)     self._px=x; self._py=y end
    function ps:getPosition()        return self._px or 0, self._py or 0 end
    function ps:start()              self._emitting=true end
    function ps:stop()               self._emitting=false end
    function ps:pause()              self._emitting=false end
    function ps:reset()              self._particles={} end
    function ps:isActive()           return self._emitting end
    function ps:isPaused()           return not self._emitting end
    function ps:isStopped()          return not self._emitting end
    function ps:getCount()           return #self._particles end
    function ps:emit(n)
        for i=1,n do
            local angle = (self._dir or 0) + math.random() * (self._spread or 0) - (self._spread or 0)/2
            local speed = self._minspeed + math.random()*(self._maxspeed-self._minspeed)
            table.insert(self._particles, {
                x=self._px or 0, y=self._py or 0,
                vx=math.cos(angle)*speed, vy=math.sin(angle)*speed,
                life=self._minlife + math.random()*(self._maxlife-self._minlife),
                age=0,
            })
        end
    end
    function ps:update(dt)
        if self._emitting then
            self._timer = (self._timer or 0) + dt
            local count = math.floor(self._timer * self._rate)
            if count > 0 then self:emit(count); self._timer = self._timer - count/self._rate end
        end
        local alive = {}
        for _, p in ipairs(self._particles) do
            p.age = p.age + dt
            if p.age < p.life then
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                alive[#alive+1] = p
            end
        end
        self._particles = alive
    end
    function ps:_draw(x,y)
        for _, p in ipairs(self._particles) do
            love.graphics.draw(self._image, p.x+(x or 0), p.y+(y or 0))
        end
    end
    function ps:clone()
        return love.graphics.newParticleSystem(self._image, self._buffer)
    end
    return ps
end

-- ──────────────────────────────────────────────────────────────
-- Debug system info (internal utility, not part of LÖVE API)
-- ──────────────────────────────────────────────────────────────
function ___displaySystemInfo()
    local currRam  = math.floor((os.ram()      / 1000000) * 100) / 100
    local totalRam = math.floor((os.totalram() / 1000000) * 100) / 100
    currRam = totalRam - currRam
    local fnt      = lv1lua.current.font.font
    local dbgColor = color.new(0, 255, 0, 255)
    local sz       = 12 / 18.5
    screen.print(fnt, 10, 10, "FPS: "..screen.frame().."/"..screen.fps(), sz, dbgColor)
    screen.print(fnt, 10, 30, "RAM: "..currRam.."/"..totalRam.."MB",       sz, dbgColor)
    screen.print(fnt, 10, 50, "CPU: "..os.cpu().."/444Mhz",                sz, dbgColor)
    screen.print(fnt, 10, 70, "GPU: "..os.gpuclock().."/166Mhz",           sz, dbgColor)
    screen.print(fnt, 10, 90, "GPU CROSS: "..os.crossbarclock().."/222Mhz",sz, dbgColor)
end
