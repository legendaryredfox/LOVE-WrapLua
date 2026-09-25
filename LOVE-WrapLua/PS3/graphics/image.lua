-- PS3 graphics: Image, Quad, and the draw call.

function love.graphics.newImage(filename, settings)
    local img = surface()
    img:LoadIMG(lv1lua.dataloc .. "game/" .. filename)
    return img
end

-- Only position is honoured: the PS3 Lua Player blits a surface as-is, with no
-- scale or rotation. A quad in argument 2 is accepted so quad-based libraries
-- (anim8 / desAnim8) run here, but the Lua Player exposes no sub-rect blit, so
-- the quad is ignored and the whole surface is drawn at (x, y). Documented in
-- Implemented.md; PS3 is the least-supported tier (T8.5).
function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy)
    if drawable == nil then return end
    -- SpriteBatch / Text replay themselves through this same entry point
    -- (core/objects.lua); without this they would reach setRectPos as a plain
    -- Lua table and error.
    if lv1lua.util.isDrawObject(drawable) then
        return drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
    end

    local x = xOrQuad
    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        -- draw(drawable, quad, x, y, r, sx, sy, ox, oy): drop the quad, shift.
        x, y, sx, sy, ox, oy = y, r, sy, ox, oy, nil
    end
    x, y = (x or 0) - (ox or 0) * math.abs(sx or 1),
           (y or 0) - (oy or 0) * math.abs(sy or 1)
    x = x * lv1lua.gfx.scale
    y = y * lv1lua.gfx.scale + lv1lua.gfx.yOffset
    if drawable then
        drawable:setRectPos(x, y)
        BlitToScreen(drawable)
    end
end

function love.graphics.newQuad(x, y, w, h, swOrImg, sh)
    local sw
    if type(swOrImg) == "number" then
        sw = swOrImg
    elseif swOrImg ~= nil then
        -- A drawable: a PS3 surface answers getWidth/getHeight.
        sw = swOrImg.getWidth  and swOrImg:getWidth()  or w
        sh = swOrImg.getHeight and swOrImg:getHeight() or h
    end
    local q = { x=x, y=y, width=w, height=h, sw=sw or w, sh=sh or h }
    function q:getViewport() return self.x, self.y, self.width, self.height end
    function q:setViewport(x, y, w, h) self.x, self.y, self.width, self.height = x, y, w, h end
    function q:getTextureDimensions() return self.sw, self.sh end
    return q
end
