-- PS3 graphics: Image, Quad, and the draw call.
-- Images are loaded with gfx.LoadTexture and drawn as textured quads via
-- gfx.SetPolygon / VertexPosition / VertexTexture / VertexColor / End.
-- Rotation is computed in Lua (no dependency on gfx.MatrixSetModelView in 2D).

-- Returns 4 screen-space quad corners with rotation around the anchor point.
-- px, py:  top-left of the unrotated quad
-- sw, sh:  screen-space size
-- r:       rotation in radians
-- ox, oy:  anchor offset from top-left (the point that stays fixed under rotation)
local function quadVerts(px, py, sw, sh, r, ox, oy)
    if r == 0 then
        return px,    py,
               px+sw, py,
               px+sw, py+sh,
               px,    py+sh
    end
    local cx, cy = px + ox, py + oy
    local cs, sn = math.cos(r), math.sin(r)
    local function rot(x, y)
        return cx + x*cs - y*sn,
               cy + x*sn + y*cs
    end
    local x1, y1 = rot(-ox,    -oy)
    local x2, y2 = rot(sw-ox, -oy)
    local x3, y3 = rot(sw-ox, sh-oy)
    local x4, y4 = rot(-ox,   sh-oy)
    return x1, y1, x2, y2, x3, y3, x4, y4
end

function love.graphics.newImage(filename, settings)
    local g = rawget(_G, "gfx")
    local handle = g and g.LoadTexture and g.LoadTexture(lv1lua.dataloc .. "game/" .. filename)
    local w = (handle and handle.getWidth  and handle:getWidth())  or 64
    local h = (handle and handle.getHeight and handle:getHeight()) or 64
    lv1lua.core.validateTexture(w, h, filename)
    local img = { _tex = handle, _w = w, _h = h }
    function img:getWidth()      return self._w end
    function img:getHeight()     return self._h end
    function img:getDimensions() return self._w, self._h end
    return img
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy, kx)
    if drawable == nil then return end
    if lv1lua.util.isDrawObject(drawable) then
        return drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
    end
    local g = rawget(_G, "gfx")
    if not (g and g.SetPolygon and drawable._tex) then return end

    local stack = lv1lua.gfx.transform
    stack:updateTransform()
    local t = stack.transform

    local _x, _y, _r, _sx, _sy, _ox, _oy
    local u0, v0, u1, v1 = 0, 0, 1, 1

    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        -- draw(drawable, quad, x, y, r, sx, sy, ox, oy)
        _x,  _y  = y  or 0, r  or 0
        _r       = sx
        _sx      = (sy  == nil) and t._scaleX or sy  * t._scaleX
        _sy      = (ox  == nil) and t._scaleY or ox  * t._scaleY
        _ox, _oy = oy or 0, kx or 0
        local qx, qy, qw, qh = xOrQuad:getViewport()
        local tw, th         = xOrQuad:getTextureDimensions()
        u0, v0 = qx/tw,       qy/th
        u1, v1 = (qx+qw)/tw,  (qy+qh)/th
    else
        -- draw(drawable, x, y, r, sx, sy, ox, oy)
        _x,  _y  = xOrQuad or 0, y or 0
        _r       = r
        _sx      = (sx  == nil) and t._scaleX or sx  * t._scaleX
        _sy      = (sy  == nil) and t._scaleY or sy  * t._scaleY
        _ox, _oy = ox or 0, oy or 0
    end

    local absSx   = math.abs(_sx or 1)
    local absSy   = math.abs(_sy or 1)
    local gscale  = lv1lua.gfx.scale
    local yo      = lv1lua.gfx.yOffset
    local sw      = drawable._w * absSx * gscale
    local sh      = drawable._h * absSy * gscale

    -- anchor: the screen-space position of the (ox, oy) handle point
    local anchorX = (_x * t._scaleX + t._offsetX) * gscale
    local anchorY = (_y * t._scaleY + t._offsetY) * gscale + yo
    local ox_s    = _ox * absSx * gscale
    local oy_s    = _oy * absSy * gscale

    local rot  = (_r or 0) + t._rotation
    local rgba = lv1lua.current.colorRGBA
    local cr, cg, cb, ca = rgba[1], rgba[2], rgba[3], rgba[4]

    -- top-left = anchor minus the anchor offset
    local px, py = anchorX - ox_s, anchorY - oy_s
    local x1, y1, x2, y2, x3, y3, x4, y4 = quadVerts(px, py, sw, sh, rot, ox_s, oy_s)

    g.SetTexture(drawable._tex)
    g.SetPolygon(g.QUADS, 0)
    g.VertexPosition(x1, y1, 0); g.VertexTexture(u0, v0); g.VertexColor(cr, cg, cb, ca)
    g.VertexPosition(x2, y2, 0); g.VertexTexture(u1, v0); g.VertexColor(cr, cg, cb, ca)
    g.VertexPosition(x3, y3, 0); g.VertexTexture(u1, v1); g.VertexColor(cr, cg, cb, ca)
    g.VertexPosition(x4, y4, 0); g.VertexTexture(u0, v1); g.VertexColor(cr, cg, cb, ca)
    g.End()
end

function love.graphics.newQuad(x, y, w, h, swOrImg, sh)
    local sw
    if type(swOrImg) == "number" then
        sw = swOrImg
    elseif swOrImg ~= nil then
        sw = swOrImg._w  or (swOrImg.getWidth  and swOrImg:getWidth()  or w)
        sh = swOrImg._h  or (swOrImg.getHeight and swOrImg:getHeight() or h)
    end
    local q = { x=x, y=y, width=w, height=h, sw=sw or w, sh=sh or h }
    function q:getViewport()            return self.x, self.y, self.width, self.height end
    function q:setViewport(x, y, w, h)  self.x, self.y, self.width, self.height = x, y, w, h end
    function q:getTextureDimensions()   return self.sw, self.sh end
    return q
end
