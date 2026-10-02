-- lpp-3ds draw pipeline. Graphics.drawImageExtended takes the screen constant as
-- its last argument; both draw forms map onto it, with a fallback to
-- Graphics.drawImage for the simple unrotated/unscaled case.
--
-- lpp-3ds drawImageExtended does not accept a tint color, so setColor RGB is
-- applied to images as alpha-only (same as PSP quad draws with a non-white color).

local stack = lv1lua.gfx.transform

local function compose(x, y, r, sx, sy, ox, oy, srcW, srcH)
    stack:updateTransform()
    local t = stack.transform
    local lsx = (sx or 1) * t._scaleX
    local lsy = (sy or 1) * t._scaleY
    local dx  = x * t._scaleX + t._offsetX - (ox or 0) * math.abs(lsx)
    local dy  = y * t._scaleY + t._offsetY - (oy or 0) * math.abs(lsy)
    local rad = (r or 0) + t._rotation
    return dx, dy, rad, lsx, lsy, srcW * math.abs(lsx), srcH * math.abs(lsy)
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy, kx, ky)
    if lv1lua.util.isDrawObject(drawable) then
        drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
        return
    end
    if not drawable then return end

    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        local qx, qy, qw, qh = xOrQuad:getViewport()
        qx, qy, qw, qh = lv1lua.core.insetQuad(qx, qy, qw, qh)
        local dsy = (ox == nil) and sy or ox
        local dx, dy, rad, lsx, lsy, bw, bh =
            compose(y or 0, r or 0, sx or 0, sy or 1, dsy or 1, oy, kx, qw, qh)
        if lv1lua.gfx.scissorRejects(dx, dy, bw, bh) then return end
        Graphics.drawImageExtended(dx, dy, drawable, qx, qy, qw, qh,
                                   rad, lsx, lsy, TOP_SCREEN)
        return
    end

    local w = Graphics.getImageWidth(drawable)
    local h = Graphics.getImageHeight(drawable)
    local dx, dy, rad, lsx, lsy, bw, bh =
        compose(xOrQuad or 0, y or 0, r or 0, sx or 1, sy or sx or 1, ox, oy, w, h)
    if lv1lua.gfx.scissorRejects(dx, dy, bw, bh) then return end

    if rad ~= 0 or lsx ~= 1 or lsy ~= 1 then
        Graphics.drawImageExtended(dx, dy, drawable, 0, 0, w, h,
                                   rad, lsx, lsy, TOP_SCREEN)
    else
        Graphics.drawImage(dx, dy, drawable, TOP_SCREEN)
    end
end
