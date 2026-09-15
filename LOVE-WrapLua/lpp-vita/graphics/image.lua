-- lpp-vita graphics: Image and Quad.
--
-- Graphics.loadImage returns a native texture handle, which the wrapper passes
-- straight through: games treat it as an opaque drawable.

function love.graphics.newImage(filename, settings)
    return Graphics.loadImage(lv1lua.dataloc .. "game/" .. filename)
end

function love.graphics.newQuad(x, y, w, h, swOrImg, sh)
    local sw, _sh
    if type(swOrImg) == "table" then
        sw  = swOrImg.getDimensions and swOrImg:getDimensions() or w
        _sh = sh
    else
        sw  = swOrImg or w
        _sh = sh or h
    end
    local q = { x=x, y=y, width=w, height=h, sw=sw, sh=_sh }
    function q:getViewport() return self.x, self.y, self.width, self.height end
    function q:setViewport(x, y, w, h) self.x, self.y, self.width, self.height = x, y, w, h end
    function q:getTextureDimensions() return self.sw, self.sh end
    return q
end
