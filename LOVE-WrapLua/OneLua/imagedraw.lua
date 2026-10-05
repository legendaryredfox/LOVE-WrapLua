-- OneLua image draw, shared by the Vita (graphics/) and PSP (psp/) backends.
--
-- Both run the same image.* SDK, which blits a whole image or a sub-rect at
-- one position with an absolute rotation and nothing else: no scale, no
-- mirroring. So a scaled or mirrored draw blits a private copy, built once per
-- (source, sx, sy) and flipped there; the shared source handle is never
-- resized or flipped, because every Image and Quad cut from it reads it.
--
-- What differs between the two consoles is a hook on lv1lua.gfx:
--   blitImage(img, x, y)   whole-image blit honouring colour (and blend, PSP)
--   prepareCopy(img)       optional: settle a fresh copy (filter, Vita)
--   snap(v)                optional: snap a blit position to whole pixels

local gfx   = lv1lua.gfx
local stack = gfx.transform

-- Weak keys let unused copies be collected, which matters on a 32MB PSP.
local cache = setmetatable({}, { __mode = "k" })

local function scaledCopy(src, sx, sy)
    local e = cache[src]
    if not e or e.sx ~= sx or e.sy ~= sy or not e.img then
        local img = image.copyscale(src, image.getrealw(src) * math.abs(sx),
                                         image.getrealh(src) * math.abs(sy))
        if sx < 0 then image.fliph(img) end
        if sy < 0 then image.flipv(img) end
        if gfx.prepareCopy then gfx.prepareCopy(img) end
        e = { img = img, sx = sx, sy = sy }
        cache[src] = e
    end
    return e.img
end

-- The anchor maps as a point (p * S + O), the scale multiplies and the
-- rotation adds; the origin offset is applied afterwards in the folded scale,
-- so it stays a pivot in image pixels as in LOVE.
local function fold(x, y, r, sx, sy)
    stack:updateTransform()
    local t = stack.transform
    sx = sx or 1; sy = sy or sx
    return (x or 0) * t._scaleX + t._offsetX, (y or 0) * t._scaleY + t._offsetY,
           (r or 0) + t._rotation, sx * t._scaleX, sy * t._scaleY
end

local function screen(x, y)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x, y = x * gfx.scale, y * gfx.scale
    end
    if gfx.snap then x, y = gfx.snap(x), gfx.snap(y) end
    return x, y
end

-- Always set the rotation, including 0, so an earlier rotated draw cannot
-- leave this image tilted on a later upright one.
local function rotate(img, r)
    image.rotate(img, (r / math.pi) * 180)
end

-- draw(drawable, quad, x, y, r, sx, sy, ox, oy). Rotation turns the whole
-- copy: the SDK has no per-region rotate.
local function quadDraw(tex, quad, x, y, r, sx, sy, ox, oy)
    x, y, r, sx, sy = fold(x, y, r, sx, sy)
    local qx, qy, qw, qh = lv1lua.core.insetQuad(quad:getViewport())
    x = x - (ox or 0) * math.abs(sx)
    y = y - (oy or 0) * math.abs(sy)
    -- A mirrored draw grows left/up from the anchor, as it does in LOVE.
    if sx < 0 then x = x + qw * sx end
    if sy < 0 then y = y + qh * sy end

    local img, sqx, sqy, sqw, sqh = tex, qx, qy, qw, qh
    if sx ~= 1 or sy ~= 1 then
        img = scaledCopy(tex, sx, sy)
        local asx, asy = math.abs(sx), math.abs(sy)
        sqx, sqy, sqw, sqh = qx * asx, qy * asy, qw * asx, qh * asy
        -- The copy is already mirrored; find the sub-rect inside it.
        if sx < 0 then sqx = image.getrealw(img) - sqx - sqw end
        if sy < 0 then sqy = image.getrealh(img) - sqy - sqh end
    end

    x, y = screen(x, y)
    rotate(img, r)
    image.blit(img, x, y, sqx, sqy, sqw, sqh, color.a(lv1lua.current.color))
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy)
    if drawable == nil then return end
    -- SpriteBatch, Text, ParticleSystem and Canvas replay themselves through
    -- this same entry point (core/objects.lua).
    if lv1lua.util.isDrawObject(drawable) then
        return drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
    end
    local tex = lv1lua.core.texture(drawable)
    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        return quadDraw(tex, xOrQuad, y, r, sx, sy, ox, oy)
    end

    local x
    x, y, r, sx, sy = fold(xOrQuad, y, r, sx, sy)
    x = x - (ox or 0) * math.abs(sx)
    y = y - (oy or 0) * math.abs(sy)
    if sx < 0 then x = x + image.getrealw(tex) * sx end
    if sy < 0 then y = y + image.getrealh(tex) * sy end

    local img = tex
    if sx ~= 1 or sy ~= 1 then img = scaledCopy(tex, sx, sy) end

    x, y = screen(x, y)
    rotate(img, r)
    gfx.blitImage(img, x, y)
end
