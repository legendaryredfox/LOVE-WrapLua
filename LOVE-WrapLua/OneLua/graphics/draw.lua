-- OneLua graphics: the draw pipeline.

local util  = lv1lua.util
local stack = lv1lua.gfx.transform

-- Loaded images are immutable sources. Scaling makes a transient copy keyed by
-- (source, sx, sy) so the same image can be drawn at different scales in one
-- frame without corrupting the shared drawable (#6). Weak keys let unused
-- copies be collected.
local _scaledCache = setmetatable({}, { __mode = "k" })

local function _scaledCopy(src, sx, sy)
    local e = _scaledCache[src]
    if not e or e.sx ~= sx or e.sy ~= sy or not e.img then
        local w = image.getrealw(src) * sx
        local h = image.getrealh(src) * sy
        e = { img = image.copyscale(src, w, h), sx = sx, sy = sy }
        _scaledCache[src] = e
    end
    return e.img
end

function love.graphics._defaultDraw(drawable, x, y, r, sx, sy, xf, yf, w, h)
    if drawable == nil then print("No drawable"); return end
    x = x or 0; y = y or 0
    if sx and not sy then sy = sx end

    if lv1luaconf.imgscale == true or lv1luaconf.resscale == true then
        x = x * lv1lua.gfx.scale; y = y * lv1lua.gfx.scale
    end

    stack:updateTransform()
    local rot = (r or 0) + stack.transform._rotation

    -- Draw a cached scaled copy instead of resizing the source in place.
    local img = drawable
    if sx and (sx ~= 1 or sy ~= 1) then
        img = _scaledCopy(drawable, sx, sy)
        image.setfilter(img, lv1lua.gfx.filter.mag, lv1lua.gfx.filter.min)
    end

    -- Always set absolute rotation (including 0) so a prior rotated draw does
    -- not leave this drawable tilted on a later upright draw.
    image.rotate(img, (rot / math.pi) * 180)

    if xf ~= nil then
        image.blit(img, x, y, xf, yf, w, h, color.a(lv1lua.current.color))
    else
        image.blit(img, x, y, color.a(lv1lua.current.color))
    end
end

function love.graphics.draw(drawable, xOrQuad, y, r, sx, sy, ox, oy, kx, ky)
    -- SpriteBatch / Text / ParticleSystem objects draw themselves.
    if lv1lua.util.isDrawObject(drawable) then
        drawable:_draw(xOrQuad, y, r, sx, sy, ox, oy)
        return
    end

    local isNew = (type(drawable) == "table")
    stack:updateTransform()
    local transform = stack.transform
    local _x, _y, _r, _sx, _sy

    if type(xOrQuad) == "table" and xOrQuad.getViewport then
        -- draw(drawable, quad, x, y, r, sx, sy, ox, oy)
        _x  = (y  == nil) and transform._offsetX or y  + transform._offsetX
        _y  = (r  == nil) and transform._offsetY or r  + transform._offsetY
        _r  = sx
        _sx = (sy == nil) and transform._scaleX  or sy * transform._scaleX
        _sy = (ox == nil) and transform._scaleY  or ox * transform._scaleY
        ox, oy = oy or 0, kx or 0
        local absSx, absSy = math.abs(_sx), math.abs(_sy)
        -- Same destination formula as the plain-image path below: the two used
        -- to disagree once a scale was active, so the same sprite landed in
        -- two different places depending on whether a quad was passed.
        _x = util.round((_x - ox * absSx))
        _y = util.round((_y - oy * absSy))
        if isNew then
            _x, _y = drawable:__handleNegativeScale(_x, _y, _sx, _sy)
            xOrQuad:draw(drawable.imgData, _x, _y, _r, absSx, absSy)
        else
            xOrQuad:draw(drawable, _x, _y, _r, absSx, absSy)
        end
    else
        -- draw(drawable, x, y, r, sx, sy, ox, oy)
        _x  = (xOrQuad == nil) and 0 or xOrQuad
        _y  = y  or 0
        _sx = (sx == nil) and transform._scaleX or sx * transform._scaleX
        _sy = (sy == nil) and transform._scaleY or sy * transform._scaleY
        ox, oy = ox or 0, oy or 0
        local absSx, absSy = math.abs(_sx), math.abs(_sy)
        _x = util.round((_x - ox * absSx) + transform._offsetX * absSx)
        _y = util.round((_y - oy * absSy) + transform._offsetY * absSy)
        if isNew then
            _x, _y = drawable:__handleNegativeScale(_x, _y, _sx, _sy)
            love.graphics._defaultDraw(drawable.imgData, _x, _y, r, absSx, absSy)
        else
            love.graphics._defaultDraw(drawable, _x, _y, r, absSx, absSy)
        end
    end
end
