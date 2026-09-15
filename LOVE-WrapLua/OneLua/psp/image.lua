-- PSP graphics: Image, Quad and the draw call.

function love.graphics.newImage(filename, settings)
    local img = image.load(lv1lua.dataloc .. "game/" .. filename)
    if lv1luaconf.imgscale == true then
        image.scale(img, lv1lua.gfx.scale * 100)
    end
    return img
end

-- Known limitation: rotation and scale are applied to the handle itself, so
-- drawing one image twice in a frame at different scales leaves the source
-- mutated. The Vita path solves this with a cached scaled copy
-- (OneLua/graphics/draw.lua); the same fix is still owed here (FIX_PLAN #6).
function love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy)
    x, y = (x or 0) - (ox or 0) * math.abs(sx or 1),
           (y or 0) - (oy or 0) * math.abs(sy or 1)
    if sx and not sy then sy = sx end
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s
    end
    if r then image.rotate(drawable, (r / math.pi) * 180) end
    if sx then
        image.resize(drawable, image.getrealw(drawable) * sx,
                               image.getrealh(drawable) * sy)
    end
    if drawable then
        image.blit(drawable, x, y, color.a(lv1lua.current.color))
    end
end

function love.graphics.newQuad(x, y, width, height, swOrImg, sh)
    local sw, _sh
    if type(swOrImg) == "table" then
        sw  = swOrImg.imageWidth  or width
        _sh = swOrImg.imageHeight or height
    else
        sw  = swOrImg
        _sh = sh
    end
    local q = {
        x = x or 0, y = y or 0,
        width = width or 0, height = height or 0,
        imageWidth = sw or width, imageHeight = _sh or height,
    }
    function q:getViewport() return self.x, self.y, self.width, self.height end
    function q:setViewport(x, y, w, h, sw, sh)
        self.x      = x or self.x
        self.y      = y or self.y
        self.width  = w or self.width
        self.height = h or self.height
        if sw then self.imageWidth = sw; self.imageHeight = sh end
    end
    function q:getTextureDimensions() return self.imageWidth, self.imageHeight end
    function q:getScale()
        return self.width / self.imageWidth, self.height / self.imageHeight
    end
    return q
end
