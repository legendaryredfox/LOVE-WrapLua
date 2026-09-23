-- PSP graphics: Image, Quad and the draw call.

function love.graphics.newImage(filename, settings)
    local img = image.load(lv1lua.dataloc .. "game/" .. filename)
    -- PSP textures must be power-of-two and <=512; warn before a scale/blit
    -- silently corrupts an oversize or NPOT sheet (FIX_PLAN T8.1).
    lv1lua.core.validateTexture(image.getrealw(img), image.getrealh(img), filename)
    if lv1luaconf.imgscale == true then
        image.scale(img, lv1lua.gfx.scale * 100)
    end
    return img
end

-- Loaded images are immutable sources. Scaling makes a transient copy keyed by
-- (source, sx, sy), so the same image drawn twice in one frame at different
-- scales does not have the first draw corrupt the second (#6). Weak keys let
-- unused copies be collected, which matters on a 32MB PSP.
local _scaledCache = setmetatable({}, { __mode = "k" })

local function _scaledCopy(src, sx, sy)
    local e = _scaledCache[src]
    if not e or e.sx ~= sx or e.sy ~= sy or not e.img then
        local img = image.copyscale(src, image.getrealw(src) * math.abs(sx),
                                         image.getrealh(src) * math.abs(sy))
        -- A negative scale mirrors in LOVE. Flip the private copy; the source
        -- handle is shared and must stay untouched.
        if sx < 0 then image.fliph(img) end
        if sy < 0 then image.flipv(img) end
        e = { img = img, sx = sx, sy = sy }
        _scaledCache[src] = e
    end
    return e.img
end

-- draw(drawable, quad, x, y, r, sx, sy, ox, oy): blit a sub-rect of the sheet.
-- The source stays immutable; scale/flip reuse the cached copy from _scaledCopy
-- and the quad viewport is remapped into that copy. Rotation with a quad rotates
-- the whole copy (no per-region rotate on PSP) and is documented as limited.
local function _quadDraw(drawable, quad, x, y, r, sx, sy, ox, oy)
    sx = sx or 1; sy = sy or sx
    ox = ox or 0; oy = oy or 0
    local qx, qy, qw, qh = quad:getViewport()
    -- Half-texel inset keeps linear sampling inside the frame (T8.2).
    qx, qy, qw, qh = lv1lua.core.insetQuad(qx, qy, qw, qh)
    x = (x or 0) - ox * math.abs(sx)
    y = (y or 0) - oy * math.abs(sy)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s
    end

    local img = drawable
    local sqx, sqy, sqw, sqh = qx, qy, qw, qh
    if sx ~= 1 or sy ~= 1 then
        img = _scaledCopy(drawable, sx, sy)  -- whole sheet, scaled and flipped
        local asx, asy = math.abs(sx), math.abs(sy)
        sqx, sqy, sqw, sqh = qx * asx, qy * asy, qw * asx, qh * asy
        -- _scaledCopy already mirrored the pixels; remap the sub-rect into it.
        if sx < 0 then sqx = image.getrealw(img) - sqx - sqw end
        if sy < 0 then sqy = image.getrealh(img) - sqy - sqh end
    end

    -- A mirrored draw grows left/up from the anchor, as it does in LOVE.
    if sx < 0 then x = x + qw * sx end
    if sy < 0 then y = y + qh * sy end

    image.rotate(img, ((r or 0) / math.pi) * 180)
    image.blit(img, x, y, sqx, sqy, sqw, sqh, color.a(lv1lua.current.color))
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy)
    if drawable == nil then return end
    -- SpriteBatch / Text replay themselves through this same entry point
    -- (core/objects.lua); without this they would reach the native blit as a
    -- plain Lua table.
    if lv1lua.util.isDrawObject(drawable) then
        return drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
    end
    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        return _quadDraw(drawable, xOrQuad, y, r, sx, sy, ox, oy)
    end

    local x = xOrQuad
    sx = sx or 1
    sy = sy or sx
    x = (x or 0) - (ox or 0) * math.abs(sx)
    y = (y or 0) - (oy or 0) * math.abs(sy)
    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        local s = lv1lua.gfx.scale
        x = x * s; y = y * s
    end

    local img = drawable
    if sx ~= 1 or sy ~= 1 then
        img = _scaledCopy(drawable, sx, sy)
    end

    -- A mirrored draw grows left/up from the anchor, as it does in LOVE.
    if sx < 0 then x = x + image.getrealw(drawable) * sx end
    if sy < 0 then y = y + image.getrealh(drawable) * sy end

    -- Always set absolute rotation, including 0, so an earlier rotated draw
    -- cannot leave this image tilted on a later upright one.
    image.rotate(img, ((r or 0) / math.pi) * 180)

    image.blit(img, x, y, color.a(lv1lua.current.color))
end

function love.graphics.newQuad(x, y, width, height, swOrImg, sh)
    local sw, _sh
    if type(swOrImg) == "table" then
        sw  = swOrImg.imageWidth  or width
        _sh = swOrImg.imageHeight or height
    else
        sw  = swOrImg
        _sh = sh
    end
    lv1lua.core.validateTexture(sw, _sh, "spritesheet")
    local q = {
        x = x or 0, y = y or 0,
        width = width or 0, height = height or 0,
        imageWidth = sw or width, imageHeight = _sh or height,
    }
    function q:getViewport() return self.x, self.y, self.width, self.height end
    function q:setViewport(x, y, w, h, sw, sh)
        self.x      = x or self.x
        self.y      = y or self.y
        self.width  = w or self.width
        self.height = h or self.height
        if sw then self.imageWidth = sw; self.imageHeight = sh end
    end
    function q:getTextureDimensions() return self.imageWidth, self.imageHeight end
    function q:getScale()
        return self.width / self.imageWidth, self.height / self.imageHeight
    end
    return q
end
