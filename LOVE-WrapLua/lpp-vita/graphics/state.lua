-- lpp-vita graphics: platform constants and the native hooks core/state.lua
-- drives.

lv1lua.gfx = {
    -- Native font handle for the bundled default face. Font wrappers built in
    -- graphics/font.lua point at this when the game asks for no specific file.
    defaultFont = Font.load(lv1lua.dataloc .. "LOVE-WrapLua/Vera.ttf"),
    -- lpp-vita blits at 0.75 of LÖVE's coordinate space when scaling is on.
    scale     = 0.75,
    lineWidth = 1,

    -- Native hooks for core/state.lua. There is no clearScreen: lv1lua.draw
    -- (whileloop.lua) owns the Screen.clear/flip pair, and vita2d exposes no
    -- default-filter call.
    nativeColor = function(r, g, b, a) return Color.new(r, g, b, a) end,
}
Font.setPixelSizes(lv1lua.gfx.defaultFont, 12)

lv1lua.current = {
    -- Font wrapper object, assigned in graphics/font.lua.
    font        = nil,
    color       = Color.new(255, 255, 255, 255),
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = Color.new(0, 0, 0, 255),
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}
