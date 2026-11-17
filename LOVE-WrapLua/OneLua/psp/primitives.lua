-- PSP graphics: native primitive calls for the shared shape code
-- (core/primitives.lua).
--
-- Native order here is the plain (x1, y1, x2, y2) of OneLua's draw.* calls,
-- unlike lpp-vita, which wants both x values first.

local stack = lv1lua.gfx.transform

lv1lua.gfx.prims = {
    fillRect    = function(x, y, w, h, c) draw.fillrect(x, y, w, h, c) end,
    fillRuns    = function(runs, dx, dy, c)
        local fill = draw.fillrect
        for i = 1, #runs, 4 do fill(runs[i] + dx, runs[i + 1] + dy, runs[i + 2], runs[i + 3], c) end
    end,
    rectOutline = function(x, y, w, h, c) draw.rect(x, y, w, h, c) end,
    line        = function(x1, y1, x2, y2, c) draw.line(x1, y1, x2, y2, c) end,
    fillCircle  = function(x, y, r, c, segments) draw.circle(x, y, r, c, segments) end,

    mapPoint = function(x, y) return stack:mapPoint(x, y) end,
    mapScale = function(w, h) return stack:mapScale(w, h) end,
    mapShear = function() return stack:mapShear() end,
}
