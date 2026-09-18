-- lpp-vita graphics: the draw pipeline.
--
-- The native Graphics.drawImageExtended(x, y, tex, st_x, st_y, w, h, radius,
-- sx, sy [, color]) does quad + rotation + scale in one call, so both draw
-- forms map onto it:
--   draw(drawable, x, y, r, sx, sy, ox, oy)
--   draw(drawable, quad, x, y, r, sx, sy, ox, oy)
-- The common unrotated full-image draw keeps using drawScaleImage as a fast
-- path. (FIX_PLAN T2.1)
--
-- The software transform stack (core/transform.lua) is folded in here: its
-- flattened offset/scale/rotation compose with the per-draw arguments, and a
-- draw whose bounding box falls outside the active scissor is rejected
-- (FIX_PLAN T2.2).

local stack = lv1lua.gfx.transform

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
-- screen-space top-left, the composed scale, rotation and the source width/
-- height in screen pixels (for the scissor test). Origin/pivot is applied in
-- source pixels, hence abs(scale).
local function compose(x, y, r, sx, sy, ox, oy, srcW, srcH)
    stack:updateTransform()
    local t = stack.transform
    local lsx = (sx or 1) * t._scaleX
    local lsy = (sy or 1) * t._scaleY
    local dx  = x * t._scaleX + t._offsetX - (ox or 0) * math.abs(lsx)
    local dy  = y * t._scaleY + t._offsetY - (oy or 0) * math.abs(lsy)
    local rad = (r or 0) + t._rotation
    dx, dy, lsx, lsy = screenScale(dx, dy, lsx, lsy)
    return dx, dy, rad, lsx, lsy, srcW * math.abs(lsx), srcH * math.abs(lsy)
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy, kx, ky)
    -- SpriteBatch / Text draw themselves.
    if type(drawable) == "table" and drawable._draw then
        drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
        return
    end
    if not drawable then return end

    local color = lv1lua.current.color

    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        -- draw(drawable, quad, x, y, r, sx, sy, ox, oy)
        local qx, qy, qw, qh = xOrQuad:getViewport()
        -- Half-texel inset keeps linear sampling inside the frame (T8.2).
        qx, qy, qw, qh = lv1lua.core.insetQuad(qx, qy, qw, qh)
        local dsy = (ox == nil) and sy or ox
        local dx, dy, rad, lsx, lsy, bw, bh =
            compose(y or 0, r or 0, sx or 0, sy or 1, dsy or 1, oy, kx, qw, qh)
        if lv1lua.gfx.scissorRejects(dx, dy, bw, bh) then return end
        Graphics.drawImageExtended(dx, dy, drawable, qx, qy, qw, qh,
                                   rad, lsx, lsy, color)
        return
    end

    -- draw(drawable, x, y, r, sx, sy, ox, oy)
    local w = Graphics.getImageWidth(drawable)
    local h = Graphics.getImageHeight(drawable)
    local dx, dy, rad, lsx, lsy, bw, bh =
        compose(xOrQuad or 0, y or 0, r or 0, sx or 1, sy or sx or 1, ox, oy, w, h)
    if lv1lua.gfx.scissorRejects(dx, dy, bw, bh) then return end

    if rad ~= 0 then
        Graphics.drawImageExtended(dx, dy, drawable, 0, 0, w, h,
                                   rad, lsx, lsy, color)
    else
        Graphics.drawScaleImage(dx, dy, drawable, lsx, lsy, color)
    end
end
