-- PSP graphics: Image and Quad. The draw call is shared with the Vita build
-- (OneLua/imagedraw.lua).

function love.graphics.newImage(filename, settings)
    local img = image.load(lv1lua.dataloc .. "game/" .. filename)
    -- PSP textures must be power-of-two and <=512; warn before a scale/blit
    -- silently corrupts an oversize or NPOT sheet.
    lv1lua.core.validateTexture(image.getrealw(img), image.getrealh(img), filename)
    if lv1luaconf.imgscale == true then
        image.scale(img, lv1lua.gfx.scale * 100)
    end
    -- The game gets a shared Image object (core/image.lua); draw unwraps it.
    return lv1lua.core.wrapImage(img, image.getrealw(img), image.getrealh(img))
end

function love.graphics.newQuad(x, y, width, height, swOrImg, sh)
    local sw, _sh
    if type(swOrImg) == "number" then
        sw, _sh = swOrImg, sh
    elseif lv1lua.core.isImage(swOrImg) then
        sw, _sh = swOrImg:getDimensions()
    elseif swOrImg ~= nil then
        -- A bare native handle (a library may pass one): PSP images are native handles, so their size comes from
        -- the SDK rather than from a method on a wrapper table.
        sw  = image.getrealw(swOrImg) or width
        _sh = image.getrealh(swOrImg) or height
    else
        sw, _sh = width, height
    end
    lv1lua.core.validateTexture(sw, _sh, "spritesheet")
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
