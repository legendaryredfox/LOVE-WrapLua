-- lpp-vita graphics: Image and Quad.
--
-- Graphics.loadImage returns a native texture handle, which the wrapper passes
-- straight through: games treat it as an opaque drawable.

function love.graphics.newImage(filename, settings)
    local tex = Graphics.loadImage(lv1lua.dataloc .. "game/" .. filename)
    -- Warn if the sheet exceeds the backend texture limit (FIX_PLAN T8.1).
    lv1lua.core.validateTexture(Graphics.getImageWidth(tex), Graphics.getImageHeight(tex), filename)
    return tex
end

function love.graphics.newQuad(x, y, w, h, swOrImg, sh)
    local sw, _sh
    if type(swOrImg) == "number" then
        sw, _sh = swOrImg, sh or h
    elseif swOrImg ~= nil then
        -- A drawable: lpp-vita images are native texture handles with no
        -- methods, so the size comes from the SDK.
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
