-- lpp-vita graphics: native primitive calls for the shared shape code
-- (core/primitives.lua).
--
-- Native argument order is the footgun here: Graphics.drawLine, fillRect and
-- fillEmptyRect all take (x1, x2, y1, y2, color): both x values before both y
-- values (luaGraphics.cpp). The hooks below take LOVE's order and swap into the
-- native one in one place, so no shape has to remember it. The lpp-vita mock in
-- tests/ asserts the native order.

lv1lua.gfx.prims = {
    fillRect    = function(x, y, w, h, c) Graphics.fillRect(x, x + w, y, y + h, c) end,
    rectOutline = function(x, y, w, h, c) Graphics.fillEmptyRect(x, x + w, y, y + h, c) end,
    line        = function(x1, y1, x2, y2, c) Graphics.drawLine(x1, x2, y1, y2, c) end,
    fillCircle  = function(x, y, r, c) Graphics.fillCircle(x, y, r, c) end,
}
