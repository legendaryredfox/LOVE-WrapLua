-- PS3 graphics: Image, Quad, and the draw call.

function love.graphics.newImage(filename, settings)
    local img = surface()
    img:LoadIMG(lv1lua.dataloc .. "game/" .. filename)
    return img
end

-- Only position is honoured: the PS3 Lua Player blits a surface as-is, with no
-- scale, rotation or quad support.
function love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy)
    x, y = (x or 0) - (ox or 0) * math.abs(sx or 1),
           (y or 0) - (oy or 0) * math.abs(sy or 1)
    x = x * lv1lua.gfx.scale
    y = y * lv1lua.gfx.scale + lv1lua.gfx.yOffset
    if drawable then
        drawable:setRectPos(x, y)
        BlitToScreen(drawable)
    end
end

function love.graphics.newQuad(x, y, w, h, sw, sh)
    local q = { x=x, y=y, width=w, height=h, sw=sw or w, sh=sh or h }
    function q:getViewport() return self.x, self.y, self.width, self.height end
    function q:setViewport(x, y, w, h) self.x, self.y, self.width, self.height = x, y, w, h end
    function q:getTextureDimensions() return self.sw, self.sh end
    return q
end
