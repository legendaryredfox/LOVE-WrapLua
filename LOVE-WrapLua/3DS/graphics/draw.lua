-- lpp-3ds draw pipeline.
--
--   Graphics.drawScaleImage(x, y, tex, sx, sy [, color])     top-left corner
--   Graphics.drawImageExtended(x, y, st_x, st_y, w, h, rad, sx, sy, tex
--                              [, color])                    CENTRE of the rect
--
-- drawImageExtended is sf2d_draw_texture_part_rotate_scale: it centres the
-- scaled sub-rect on (x, y) and rotates around it, and it takes the texture
-- tenth. Both forms tint with the colour argument, so setColor reaches every
-- draw. The source origin is read with luaL_checkinteger, hence the whole-texel
-- inset.

local stack = lv1lua.gfx.transform
local util  = lv1lua.util
local gfx   = lv1lua.gfx

-- Screen-space pivot, composed rotation and composed (signed) scale.
local function compose(x, y, r, sx, sy)
    stack:updateTransform()
    local t = stack.transform
    return x * t._scaleX + t._offsetX, y * t._scaleY + t._offsetY,
           (r or 0) + t._rotation, (sx or 1) * t._scaleX, (sy or 1) * t._scaleY
end

local function drawExtended(drawable, px, py, rad, lsx, lsy, ox, oy, qx, qy, qw, qh)
    local cx, cy = util.spriteCentre(px, py, rad, lsx, lsy, ox, oy, qw, qh)
    if gfx.scissorRejects(util.spriteBox(cx, cy, rad, qw * lsx, qh * lsy)) then return end
    Graphics.drawImageExtended(cx, cy, qx, qy, qw, qh, rad, lsx, lsy, drawable,
                               lv1lua.current.color)
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy, kx, ky)
    if util.isDrawObject(drawable) then
        drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
        return
    end
    if not drawable or not gfx.canDraw() then return end
    drawable = lv1lua.core.texture(drawable)

    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        -- draw(drawable, quad, x, y, r, sx, sy, ox, oy)
        local qx, qy, qw, qh = lv1lua.core.insetQuadTexels(xOrQuad:getViewport())
        local qsx = sy or 1
        local qsy = ox
        if qsy == nil then qsy = qsx end
        local px, py, rad, lsx, lsy = compose(y or 0, r or 0, sx or 0, qsx, qsy)
        drawExtended(drawable, px, py, rad, lsx, lsy, oy, kx, qx, qy, qw, qh)
        return
    end

    local w = Graphics.getImageWidth(drawable)
    local h = Graphics.getImageHeight(drawable)
    local px, py, rad, lsx, lsy = compose(xOrQuad or 0, y or 0, r or 0, sx or 1, sy or sx or 1)

    if rad ~= 0 then
        drawExtended(drawable, px, py, rad, lsx, lsy, ox, oy, 0, 0, w, h)
        return
    end

    local dx = px - (ox or 0) * lsx
    local dy = py - (oy or 0) * lsy
    local bw, bh = w * lsx, h * lsy
    local bx = bw < 0 and dx + bw or dx
    local by = bh < 0 and dy + bh or dy
    if gfx.scissorRejects(bx, by, math.abs(bw), math.abs(bh)) then return end
    Graphics.drawScaleImage(dx, dy, drawable, lsx, lsy, lv1lua.current.color)
end
