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
    transform    = nil,  -- transform stack, built in graphics/transform.lua

    -- Native hooks for core/state.lua.
    nativeColor  = function(r, g, b, a) return color.new(r, g, b, a) end,
    clearScreen  = function(native) screen.clear(native) end,
    filterValue  = function(name)
        if name == "linear" then return __IMG_FILTER_LINEAR end
        if name == "nearest" or name == "point" then return __IMG_FILTER_POINT end
        return name
    end,
}

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
