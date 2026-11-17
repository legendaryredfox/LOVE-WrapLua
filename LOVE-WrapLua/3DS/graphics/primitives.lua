-- lpp-3ds primitive hooks for core/primitives.lua.
--
-- Native order is lpp-vita's: fillRect / fillEmptyRect / drawLine take
-- (x1, x2, y1, y2, color), both x values before both y values, with no screen
-- argument (initBlend chose it). drawCircle is the filled circle and reads its
-- radius as an integer.

local stack = lv1lua.gfx.transform
local gfx   = lv1lua.gfx

gfx.prims = {
    fillRect = function(x, y, w, h, c)
        if gfx.canDraw() then Graphics.fillRect(x, x + w, y, y + h, c) end
    end,
    fillRuns = function(runs, dx, dy, c)
        if not gfx.canDraw() then return end
        local fill = Graphics.fillRect
        for i = 1, #runs, 4 do
            local x, y = runs[i] + dx, runs[i + 1] + dy
            fill(x, x + runs[i + 2], y, y + runs[i + 3], c)
        end
    end,
    rectOutline = function(x, y, w, h, c)
        if gfx.canDraw() then Graphics.fillEmptyRect(x, x + w, y, y + h, c) end
    end,
    line = function(x1, y1, x2, y2, c)
        if gfx.canDraw() then Graphics.drawLine(x1, x2, y1, y2, c) end
    end,
    fillCircle = function(x, y, r, c)
        if gfx.canDraw() then Graphics.drawCircle(x, y, math.floor(r + 0.5), c) end
    end,

    mapPoint = function(x, y) return stack:mapPoint(x, y) end,
    mapScale = function(w, h) return stack:mapScale(w, h) end,
    mapShear = function() return stack:mapShear() end,
}
