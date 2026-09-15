-- OneLua graphics: Image and Quad objects.

-- Compatibility: OneLua's image.getw/geth expect a raw handle, while our
-- drawables wrap one. Route wrapped drawables to the "real" dimension calls.
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

function love.graphics.newImage(filename, settings)
    local img = image.load(lv1lua.dataloc .. "game/" .. filename)
    if lv1luaconf.imgscale == true then
        image.scale(img, lv1lua.gfx.scale * 100)
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
    -- OneLua has no negative scaling: flip the handle instead, tracking the
    -- current flip state so repeated draws don't double-flip.
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

function love.graphics.newQuad(x, y, width, height, swOrImg, sh)
    -- Accepts (x,y,w,h, image) or (x,y,w,h, sw,sh).
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
    -- Blitting a sub-rect at a scale needs a scaled copy of the whole sheet;
    -- keep one per quad and rebuild it only when the scale changes.
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
