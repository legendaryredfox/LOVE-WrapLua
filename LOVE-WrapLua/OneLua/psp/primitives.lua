-- PSP graphics: native primitive calls for the shared shape code
-- (core/primitives.lua).
--
-- Native order here is the plain (x1, y1, x2, y2) of OneLua's draw.* calls,
-- unlike lpp-vita, which wants both x values first. The PSP has no transform
-- stack, so there is no mapRect / mapRadius.

lv1lua.gfx.prims = {
    fillRect    = function(x, y, w, h, c) draw.fillrect(x, y, w, h, c) end,
    rectOutline = function(x, y, w, h, c) draw.rect(x, y, w, h, c) end,
    line        = function(x1, y1, x2, y2, c) draw.line(x1, y1, x2, y2, c) end,
    fillCircle  = function(x, y, r, c, segments) draw.circle(x, y, r, c, segments) end,
}
