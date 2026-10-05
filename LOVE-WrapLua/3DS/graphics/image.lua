-- lpp-3ds graphics: Image and Quad. Graphics.loadImage returns the texture as
-- an integer; the game gets a shared Image object (core/image.lua) around it.
-- sf2d has no per-texture filter binding, so filters are tracked only.

lv1lua.gfx.imageHooks = {
    release = function(tex) Graphics.freeImage(tex) end,
}

function love.graphics.newImage(filename, settings)
    local tex = Graphics.loadImage(lv1lua.dataloc .. "game/" .. filename)
    local w, h = Graphics.getImageWidth(tex), Graphics.getImageHeight(tex)
    lv1lua.core.validateTexture(w, h, filename)
    return lv1lua.core.wrapImage(tex, w, h)
end

function love.graphics.newQuad(x, y, w, h, swOrImg, sh)
    local sw, _sh
    -- Graphics.loadImage returns the texture as an integer, so a number in the
    -- fifth slot is only a width when a height follows it.
    if type(swOrImg) == "number" and sh ~= nil then
        sw, _sh = swOrImg, sh
    elseif lv1lua.core.isImage(swOrImg) then
        sw, _sh = swOrImg:getDimensions()
    elseif swOrImg ~= nil then
        sw  = Graphics.getImageWidth(swOrImg)  or w
        _sh = Graphics.getImageHeight(swOrImg) or h
    else
        sw, _sh = w, h
    end
    lv1lua.core.validateTexture(sw, _sh, "spritesheet")
    local q = { x=x, y=y, width=w, height=h, sw=sw, sh=_sh }
    function q:getViewport() return self.x, self.y, self.width, self.height end
    function q:setViewport(x, y, w, h) self.x, self.y, self.width, self.height = x, y, w, h end
    function q:getTextureDimensions() return self.sw, self.sh end
    return q
end
