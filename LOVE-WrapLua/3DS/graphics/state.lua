lv1lua.gfx = {
    defaultFont = Font.load(lv1lua.dataloc .. "LOVE-WrapLua/Vera.ttf"),
    lineWidth   = 1,

    nativeColor = function(r, g, b, a) return Color.new(r, g, b, a) end,
}
Font.setPixelSizes(lv1lua.gfx.defaultFont, 12)

lv1lua.current = {
    font        = nil,
    color       = Color.new(255, 255, 255, 255),
    colorRGBA   = {1, 1, 1, 1},
    bgcolor     = Color.new(0, 0, 0, 255),
    bgColorRGBA = {0, 0, 0, 1},
    canvas      = nil,
}
