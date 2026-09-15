-- lpp-vita graphics: the draw pipeline.
--
-- Currently only the scale form is wired up. The native
-- Graphics.drawImageExtended(x, y, tex, st_x, st_y, w, h, radius, sx, sy[, col])
-- also covers quads and rotation in one call; wiring that up is FIX_PLAN T2.1.

function love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy)
    -- Origin offset is applied in source pixels, hence the abs(scale).
    x, y = (x or 0) - (ox or 0) * math.abs(sx or 1),
           (y or 0) - (oy or 0) * math.abs(sy or 1)
    r  = r  or 0
    sx = sx or 1; sy = sy or sx
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s
    end
    if lv1luaconf.imgscale == true then
        sx = sx * lv1lua.gfx.scale; sy = sy * lv1lua.gfx.scale
    end
    if drawable then
        Graphics.drawScaleImage(x, y, drawable, sx, sy, lv1lua.current.color)
    end
end
