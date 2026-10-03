-- lpp-vita graphics: the draw pipeline.
--
-- The native Graphics.drawImageExtended(x, y, tex, st_x, st_y, w, h, radius,
-- sx, sy [, color]) does quad + rotation + scale in one call, so both draw
-- forms map onto it:
--   draw(drawable, x, y, r, sx, sy, ox, oy)
--   draw(drawable, quad, x, y, r, sx, sy, ox, oy)
-- The common unrotated full-image draw keeps using drawScaleImage as a fast
-- path.
--
-- The two natives place the image differently: drawScaleImage takes the
-- top-left corner, drawImageExtended takes the CENTRE of the scaled sub-rect
-- and rotates around it (vita2d draw_texture_part_scale_rotate_generic). Both
-- are derived from LOVE's pivot + origin here, with the scale kept signed so a
-- mirrored draw (sx = -1, ox = w) stays on the pixels LOVE would cover.
--
-- The software transform stack (core/transform.lua) is folded in here: its
-- flattened offset/scale/rotation compose with the per-draw arguments, and a
-- draw whose bounding box falls outside the active scissor is rejected.

local stack = lv1lua.gfx.transform
local util  = lv1lua.util

local function screenScale(x, y, sx, sy)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s
    end
    if lv1luaconf.imgscale == true then
        sx = sx * lv1lua.gfx.scale; sy = sy * lv1lua.gfx.scale
    end
    return x, y, sx, sy
end

-- Composes a draw's arguments with the flattened transform. Returns the
-- screen-space pivot, the composed rotation and the composed (signed) scale.
local function compose(x, y, r, sx, sy)
    stack:updateTransform()
    local t = stack.transform
    local px  = x * t._scaleX + t._offsetX
    local py  = y * t._scaleY + t._offsetY
    local lsx = (sx or 1) * t._scaleX
    local lsy = (sy or 1) * t._scaleY
    px, py, lsx, lsy = screenScale(px, py, lsx, lsy)
    return px, py, (r or 0) + t._rotation, lsx, lsy
end

local function drawExtended(drawable, px, py, rad, lsx, lsy, ox, oy, qx, qy, qw, qh)
    local cx, cy = util.spriteCentre(px, py, rad, lsx, lsy, ox, oy, qw, qh)
    if lv1lua.gfx.scissorRejects(util.spriteBox(cx, cy, rad, qw * lsx, qh * lsy)) then
        return
    end
    Graphics.drawImageExtended(cx, cy, drawable, qx, qy, qw, qh,
                               rad, lsx, lsy, lv1lua.current.color)
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy, kx, ky)
    -- SpriteBatch / Text draw themselves.
    if util.isDrawObject(drawable) then
        drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
        return
    end
    if not drawable then return end

    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        -- draw(drawable, quad, x, y, r, sx, sy, ox, oy): every argument after
        -- the quad sits one slot to the right.
        local qx, qy, qw, qh = lv1lua.core.insetQuadTexels(xOrQuad:getViewport())
        local qsx = sy or 1
        local qsy = ox
        if qsy == nil then qsy = qsx end
        local px, py, rad, lsx, lsy = compose(y or 0, r or 0, sx or 0, qsx, qsy)
        drawExtended(drawable, px, py, rad, lsx, lsy, oy, kx, qx, qy, qw, qh)
        return
    end

    -- draw(drawable, x, y, r, sx, sy, ox, oy)
    local w = Graphics.getImageWidth(drawable)
    local h = Graphics.getImageHeight(drawable)
    local px, py, rad, lsx, lsy = compose(xOrQuad or 0, y or 0, r or 0, sx or 1, sy or sx or 1)

    if rad ~= 0 then
        drawExtended(drawable, px, py, rad, lsx, lsy, ox, oy, 0, 0, w, h)
        return
    end

    -- drawScaleImage spans x .. x + w*sx, so the corner is the pivot minus the
    -- signed origin; the box for the scissor runs the other way when mirrored.
    local dx = px - (ox or 0) * lsx
    local dy = py - (oy or 0) * lsy
    local bw, bh = w * lsx, h * lsy
    local bx = bw < 0 and dx + bw or dx
    local by = bh < 0 and dy + bh or dy
    if lv1lua.gfx.scissorRejects(bx, by, math.abs(bw), math.abs(bh)) then return end
    Graphics.drawScaleImage(dx, dy, drawable, lsx, lsy, lv1lua.current.color)
end
