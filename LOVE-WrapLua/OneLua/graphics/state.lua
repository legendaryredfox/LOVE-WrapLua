-- OneLua graphics: platform constants and the native hooks the shared state
-- module (core/state.lua) drives.
--
-- `lv1lua.gfx` holds everything the graphics submodules share (the transform
-- stack, the font cache, platform constants). It is internal: games only ever
-- see the love.graphics surface.

lv1lua.gfx = {
    defaultFontPath = lv1lua.dataloc .. "LOVE-WrapLua/Vera.ttf",
    -- OneLua blits at 0.75 of LÖVE's coordinate space when img/res scaling is on.
    scale        = 0.75,
    lineWidth    = 1,
    filter       = { min = 3, mag = 3, minName = "linear", magName = "linear",
                     anisotropy = 1 },
    -- screen.print takes a *scale factor* relative to a 18.5px glyph box, and
    -- anchors text on that box's baseline. The same number therefore converts a
    -- LÖVE pixel size to a native scale and shifts text to LÖVE's top-left
    -- origin.
    fontUnit     = 18.5,
    fonts        = nil,  -- font cache, built in graphics/font.lua
    transform    = nil,  -- transform stack, built by core/transformapi.lua

    -- Native hooks for core/state.lua.
    nativeColor  = function(r, g, b, a) return color.new(r, g, b, a) end,
    clearScreen  = function(native) screen.clear(native) end,
    filterValue  = function(name)
        if name == "linear" then return __IMG_FILTER_LINEAR end
        if name == "nearest" or name == "point" then return __IMG_FILTER_POINT end
        return name
    end,
}

-- Hooks for the shared OneLua draw (OneLua/imagedraw.lua). The Vita port of
-- ONElua has no additive or subtractive blit, so a whole-image draw is a tinted
-- blit when the colour is not white and a plain one otherwise.
function lv1lua.gfx.blitImage(img, x, y)
    local c = lv1lua.current
    local rgba = c.colorRGBA
    if rgba[1] ~= 1 or rgba[2] ~= 1 or rgba[3] ~= 1 then
        return image.blittint(img, x, y, c.color)
    end
    return image.blit(img, x, y, color.a(c.color))
end

-- A scaled copy takes the current default filter, as the source did.
function lv1lua.gfx.prepareCopy(img)
    local f = lv1lua.gfx.filter
    image.setfilter(img, f.mag, f.min)
end

-- LOVE blits on whole pixels.
lv1lua.gfx.snap = function(v) return lv1lua.util.round(v) end

lv1lua.current = {
    -- Font object, assigned in graphics/font.lua once newFont exists.
    font        = nil,
    color       = color.new(255, 255, 255, 255),
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = color.new(0, 0, 0, 255),
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
    blendMode   = "alpha",
}
