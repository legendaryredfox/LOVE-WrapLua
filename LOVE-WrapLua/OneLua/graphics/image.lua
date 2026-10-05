-- OneLua graphics: Image and Quad. The draw call is shared with the PSP build
-- (OneLua/imagedraw.lua).

local gfx = lv1lua.gfx

-- image.setfilter takes (image, mag, min) as native constants.
gfx.imageHooks = {
    setFilter = function(tex, min, mag)
        image.setfilter(tex, gfx.filterValue(mag), gfx.filterValue(min))
    end,
}

function love.graphics.newImage(filename, settings)
    local img = image.load(lv1lua.dataloc .. "game/" .. filename)
    lv1lua.core.validateTexture(image.getrealw(img), image.getrealh(img), filename)
    if lv1luaconf.imgscale == true then
        image.scale(img, gfx.scale * 100)
    end
    local w = lv1lua.core.wrapImage(img, image.getrealw(img), image.getrealh(img))
    -- Older libraries read the native handle from this field.
    w.imgData = img
    return w
end

function love.graphics.newQuad(x, y, width, height, swOrImg, sh)
    local sw, _sh
    if type(swOrImg) == "number" then
        sw, _sh = swOrImg, sh
    elseif lv1lua.core.isImage(swOrImg) then
        sw, _sh = swOrImg:getDimensions()
    elseif swOrImg ~= nil then
        sw  = image.getrealw(swOrImg) or width
        _sh = image.getrealh(swOrImg) or height
    else
        sw, _sh = width, height
    end
    lv1lua.core.validateTexture(sw, _sh, "spritesheet")
    local q = { x = x or 0, y = y or 0, width = width or 0, height = height or 0,
                sw = sw or width, sh = _sh or height }
    function q:getViewport() return self.x, self.y, self.width, self.height end
    function q:setViewport(x, y, w, h, sw, sh)
        self.x, self.y, self.width, self.height = x, y, w, h
        if sw then self.sw, self.sh = sw, sh end
    end
    function q:getTextureDimensions() return self.sw, self.sh end
    return q
end
