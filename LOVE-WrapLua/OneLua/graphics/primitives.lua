-- OneLua graphics: native primitive calls for the shared shape code
-- (core/primitives.lua).
--
-- OneLua's draw.* calls take the plain (x, y, w, h) / (x1, y1, x2, y2) order.
-- Rectangles and filled circles are native; every other shape is built out of
-- line segments by the shared module.

local stack = lv1lua.gfx.transform

lv1lua.gfx.prims = {
    fillRect    = function(x, y, w, h, c) draw.fillrect(x, y, w, h, c) end,
    rectOutline = function(x, y, w, h, c) draw.rect(x, y, w, h, c) end,
    line        = function(x1, y1, x2, y2, c) draw.line(x1, y1, x2, y2, c) end,
    fillCircle  = function(x, y, r, c, segments) draw.circle(x, y, r, c, segments) end,

    -- The transform stack's scale reaches a rectangle's size and a circle's
    -- radius (its translation does not; see T5.2).
    mapRect = function(x, y, w, h)
        stack:updateTransform()
        local t = stack.transform
        return x, y, w * t._scaleX, h * t._scaleY
    end,
    mapRadius = function(r)
        stack:updateTransform()
        return r * stack.transform._scaleX
    end,
}
