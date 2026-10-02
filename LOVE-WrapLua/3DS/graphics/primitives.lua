-- lpp-3ds primitive hooks for core/primitives.lua.
-- Coordinate order is LOVE's (x, y, w, h) and (x1, y1, x2, y2), unlike
-- lpp-vita which swaps both x values before both y values. The screen
-- constant is appended to every native call.

local stack = lv1lua.gfx.transform

lv1lua.gfx.prims = {
    fillRect    = function(x, y, w, h, c) Graphics.fillRect(x, y, w, h, c, TOP_SCREEN) end,
    rectOutline = function(x, y, w, h, c) Graphics.drawRect(x, y, w, h, c, TOP_SCREEN) end,
    line        = function(x1, y1, x2, y2, c) Graphics.drawLine(x1, y1, x2, y2, c, TOP_SCREEN) end,
    fillCircle  = function(x, y, r, c) Graphics.fillCircle(x, y, r, c, TOP_SCREEN) end,

    mapPoint = function(x, y)
        stack:updateTransform()
        local t = stack.transform
        return x * t._scaleX + t._offsetX, y * t._scaleY + t._offsetY
    end,
    mapScale = function(w, h)
        stack:updateTransform()
        local t = stack.transform
        return w * t._scaleX, h * t._scaleY
    end,
}
