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
-- The SDK table; `screen` below is shadowed by the coordinate helper.
local sdk   = { screen = screen }

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

-- Always set the rotation, including 0, so an earlier rotated draw cannot
-- leave this image tilted on a later upright one.
local function rotate(img, r)
    image.rotate(img, (r / math.pi) * 180)
end

-- Builds without image.copyscale (the OneLua v4R1 EBOOT.PBP for the PSP is
-- one) still scale a whole-image blit on the GPU after image.resize, but a
-- sub-rect blit ignores the size and draws 1:1. So a scaled draw resizes the
-- sheet to its final size, blits it whole, and clips to the destination
-- rectangle with screen.clip. The resize is undone straight after, because
-- the sheet is shared with every Image and Quad cut from it.
local flipCache = setmetatable({}, { __mode = "k" })

-- A private mirrored copy, one per (source, axes); the shared source is never
-- flipped. Needs no scaling, so image.copy is enough.
local function flippedCopy(src, fx, fy)
    local per = flipCache[src]
    if not per then per = {}; flipCache[src] = per end
    local key = (fx and "x" or "") .. (fy and "y" or "")
    local img = per[key]
    if not img then
        img = image.copy(src)
        if fx then image.fliph(img) end
        if fy then image.flipv(img) end
        if gfx.prepareCopy then gfx.prepareCopy(img) end
        per[key] = img
    end
    return img
end

local function round(v) return math.floor(v + 0.5) end

-- Axis-aligned bounds of the w*h rectangle at (x, y) turned by r radians
-- about (px, py).
local function turnedBounds(x, y, w, h, r, px, py)
    if r == 0 then return x, y, w, h end
    local c, s = math.cos(r), math.sin(r)
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs({ { x, y }, { x + w, y }, { x, y + h }, { x + w, y + h } }) do
        local dx, dy = p[1] - px, p[2] - py
        local rx, ry = px + dx * c - dy * s, py + dx * s + dy * c
        if rx < x1 then x1 = rx end
        if rx > x2 then x2 = rx end
        if ry < y1 then y1 = ry end
        if ry > y2 then y2 = ry end
    end
    return x1, y1, x2 - x1, y2 - y1
end

-- Draw the (sqx, sqy, sqw, sqh) rectangle of `src` with its top-left corner at
-- (x, y), enlarged by (asx, asy), turned by r about the rectangle's centre.
-- The SDK turns a blit about its own top-left corner unless image.center moves
-- the pivot (measured on the real EBOOT in PPSSPP).
local function clipBlit(src, sqx, sqy, sqw, sqh, x, y, asx, asy, r)
    local sw, sh = image.getrealw(src), image.getrealh(src)
    local w2, h2 = math.max(1, round(sw * asx)), math.max(1, round(sh * asy))
    local ex, ey = w2 / sw, h2 / sh
    local dw, dh = sqw * ex, sqh * ey
    local x0, y0 = x - sqx * ex, y - sqy * ey
    local px, py = x + dw / 2, y + dh / 2           -- turn about the rectangle's centre

    local bx, by, bw, bh = turnedBounds(x, y, dw, dh, r, px, py)
    local cx1, cy1 = math.floor(bx), math.floor(by)
    local cx2, cy2 = math.ceil(bx + bw), math.ceil(by + bh)
    -- Stay inside a scissor the game set (gfx.applyScissor re-establishes it).
    stack:updateTransform()
    local t = stack.transform
    if t._usingScissor then
        cx1, cy1 = math.max(cx1, math.floor(t._scissorX)), math.max(cy1, math.floor(t._scissorY))
        cx2 = math.min(cx2, math.ceil(t._scissorX + t._scissorWidth))
        cy2 = math.min(cy2, math.ceil(t._scissorY + t._scissorHeight))
    end
    if cx2 <= cx1 or cy2 <= cy1 then return end

    sdk.screen.clip(cx1, cy1, cx2 - cx1, cy2 - cy1)
    image.resize(src, w2, h2)
    rotate(src, r)
    if r ~= 0 then
        -- image.center(img, cx, cy) puts the sheet point (cx, cy) at the blit
        -- position and turns about it. The point is in unscaled sheet pixels
        -- (the SDK scales it with the resize). Blit with the pivot on the
        -- rectangle's centre, then put it back to the corner (0, 0).
        image.center(src, sqx + sqw / 2, sqy + sqh / 2)
        gfx.blitImage(src, px, py)
        image.center(src, 0, 0)
    else
        gfx.blitImage(src, x0, y0)
    end
    image.resize(src, sw, sh)
    if gfx.applyScissor then gfx.applyScissor() else sdk.screen.clip() end
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
    if (sx ~= 1 or sy ~= 1) and not image.copyscale then
        local asx, asy = math.abs(sx), math.abs(sy)
        local src = tex
        if sx < 0 or sy < 0 then
            src = flippedCopy(tex, sx < 0, sy < 0)
            -- The copy is mirrored; find the sub-rect inside it.
            if sx < 0 then qx = image.getrealw(tex) - qx - qw end
            if sy < 0 then qy = image.getrealh(tex) - qy - qh end
        end
        x, y = screen(x, y)
        return clipBlit(src, qx, qy, qw, qh, x, y, asx, asy, r)
    end
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

-- A quad draw takes one more argument than an image draw
-- (drawable, quad, x, y, r, sx, sy, ox, oy), so the names below are positional.
function love.graphics.draw(drawable, a, b, c, d, e, f, g, h)
    if drawable == nil then return end
    -- SpriteBatch, Text, ParticleSystem and Canvas replay themselves through
    -- this same entry point (core/objects.lua).
    if lv1lua.util.isDrawObject(drawable) then
        return drawable:_draw(a, b, c, d, e, f, g)
    end
    local tex = lv1lua.core.texture(drawable)
    if type(a) == "table" and a.getViewport then
        return quadDraw(tex, a, b, c, d, e, f, g, h)
    end

    local x, y, r, sx, sy, ox, oy = a, b, c, d, e, f, g
    x, y, r, sx, sy = fold(x, y, r, sx, sy)
    x = x - (ox or 0) * math.abs(sx)
    y = y - (oy or 0) * math.abs(sy)
    if sx < 0 then x = x + image.getrealw(tex) * sx end
    if sy < 0 then y = y + image.getrealh(tex) * sy end

    local img = tex
    if (sx ~= 1 or sy ~= 1) and not image.copyscale then
        local tw, th = image.getrealw(tex), image.getrealh(tex)
        local src = tex
        if sx < 0 or sy < 0 then src = flippedCopy(tex, sx < 0, sy < 0) end
        x, y = screen(x, y)
        return clipBlit(src, 0, 0, tw, th, x, y, math.abs(sx), math.abs(sy), r)
    end
    if sx ~= 1 or sy ~= 1 then img = scaledCopy(tex, sx, sy) end

    x, y = screen(x, y)
    rotate(img, r)
    gfx.blitImage(img, x, y)
end
