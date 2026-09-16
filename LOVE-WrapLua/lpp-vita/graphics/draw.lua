-- lpp-vita graphics: the draw pipeline.
--
-- The native Graphics.drawImageExtended(x, y, tex, st_x, st_y, w, h, radius,
-- sx, sy [, color]) does quad + rotation + scale in one call, so both draw
-- forms map onto it:
--   draw(drawable, x, y, r, sx, sy, ox, oy)
--   draw(drawable, quad, x, y, r, sx, sy, ox, oy)
-- The common unrotated full-image draw keeps using drawScaleImage as a fast
-- path. (FIX_PLAN T2.1)

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

-- Origin/pivot is applied in source pixels, hence abs(scale).
local function applyOrigin(x, y, sx, sy, ox, oy)
    return x - (ox or 0) * math.abs(sx),
           y - (oy or 0) * math.abs(sy)
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
        local dx, dy = y or 0, r or 0
        local rad    = sx or 0
        local dsx, dsy = sy or 1, (ox == nil) and (sy or 1) or ox
        local dox, doy = oy, kx
        dx, dy = applyOrigin(dx, dy, dsx, dsy, dox, doy)
        dx, dy, dsx, dsy = screenScale(dx, dy, dsx, dsy)
        Graphics.drawImageExtended(dx, dy, drawable, qx, qy, qw, qh,
                                   rad, dsx, dsy, color)
        return
    end

    -- draw(drawable, x, y, r, sx, sy, ox, oy)
    local dx, dy = xOrQuad or 0, y or 0
    local rad    = r or 0
    local dsx, dsy = sx or 1, sy or sx or 1
    dx, dy = applyOrigin(dx, dy, dsx, dsy, ox, oy)
    dx, dy, dsx, dsy = screenScale(dx, dy, dsx, dsy)

    if rad ~= 0 then
        local w = Graphics.getImageWidth(drawable)
        local h = Graphics.getImageHeight(drawable)
        Graphics.drawImageExtended(dx, dy, drawable, 0, 0, w, h,
                                   rad, dsx, dsy, color)
    else
        Graphics.drawScaleImage(dx, dy, drawable, dsx, dsy, color)
    end
end
