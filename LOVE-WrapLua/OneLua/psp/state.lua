-- PSP graphics: platform constants and the native hooks core/state.lua drives.
--
-- The PSP runs OneLua too, but with a 480x272 screen, the bundled PGF system
-- font and no transform support, so it has its own thin backend instead of
-- branching the Vita one everywhere.

lv1lua.gfx = {
    -- The PGF system font ships with OneLua; TTF loading is Vita-only.
    defaultFont = { font = font.load("oneFont.pgf"), size = 15 },
    -- PSP renders at 0.375 of LÖVE's coordinate space when scaling is on.
    scale       = 0.375,
    -- Text needs a smaller factor than geometry to stay legible at 480x272.
    fontScale   = 0.6,
    -- screen.print takes a scale factor relative to a 18.5px glyph box.
    fontUnit    = 18.5,
    lineWidth   = 1,

    -- Native hooks for core/state.lua. The PSP GPU filter is not exposed, so
    -- there is no filterValue.
    nativeColor = function(r, g, b, a) return color.new(r, g, b, a) end,
    clearScreen = function(native) screen.clear(native) end,
}

-- Blend modes (FIX_PLAN T6.5). OSLib's additive and subtractive draw effects
-- reach Lua as image.blitadd / image.blitsub, both of which take an effect
-- coefficient instead of a source rect. So the mode picks the blit here rather
-- than setting GPU state, and a quad draw (which needs the rect form) stays on
-- image.blit. Probed rather than assumed: the Vita port of ONElua ships neither.
local BLIT = {
    add      = "blitadd",
    subtract = "blitsub",
}

function lv1lua.gfx.blitWithBlend(img, x, y, alpha)
    local native = BLIT[lv1lua.current.blendMode]
    if native and type(image[native]) == "function" then
        return image[native](img, x, y, alpha)
    end
    return image.blit(img, x, y, alpha)
end

lv1lua.current = {
    -- Font object, assigned in psp/font.lua once newFont exists.
    font        = nil,
    color       = color.new(255, 255, 255, 255),
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = color.new(0, 0, 0, 255),
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}
