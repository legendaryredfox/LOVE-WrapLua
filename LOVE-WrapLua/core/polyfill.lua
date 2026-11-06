-- Shared scanline polygon fill, used by every backend's polygon("fill", …).
--
-- None of the console SDKs exposes a filled-polygon primitive, and the old
-- centroid fan was only correct for convex shapes. This fills an arbitrary
-- simple polygon (convex or concave) with the even-odd rule: for each integer
-- scanline it finds where the edges cross, sorts the crossings and fills the
-- spans between successive pairs.
--
-- A backend passes a `fillSpan(x, y, width, color)` closure that draws one
-- horizontal run with its native call (a 1px-tall filled rect or line), so this
-- module stays free of any SDK dependency.

lv1lua.core = lv1lua.core or {}

function lv1lua.core.fillPolygon(vertices, fillSpan, color)
    local n = #vertices / 2
    if n < 3 then return end

    local ymin, ymax = math.huge, -math.huge
    for i = 2, #vertices, 2 do
        local y = vertices[i]
        if y < ymin then ymin = y end
        if y > ymax then ymax = y end
    end
    ymin, ymax = math.floor(ymin + 0.5), math.floor(ymax + 0.5)

    local xs = {}
    for y = ymin, ymax do
        local yc = y + 0.5  -- sample the scanline centre to avoid vertex ties
        local count = 0
        for i = 1, n do
            local x1 = vertices[(i - 1) * 2 + 1]
            local y1 = vertices[(i - 1) * 2 + 2]
            local j  = i % n
            local x2 = vertices[j * 2 + 1]
            local y2 = vertices[j * 2 + 2]
            if (y1 <= yc and y2 > yc) or (y2 <= yc and y1 > yc) then
                count = count + 1
                xs[count] = x1 + (yc - y1) / (y2 - y1) * (x2 - x1)
            end
        end
        for a = 2, count do  -- insertion sort: spans are short
            local key, b = xs[a], a - 1
            while b >= 1 and xs[b] > key do xs[b + 1] = xs[b]; b = b - 1 end
            xs[b + 1] = key
        end
        for k = 1, count - 1, 2 do
            local xl = math.floor(xs[k] + 0.5)
            local xr = math.floor(xs[k + 1] + 0.5)
            if xr > xl then fillSpan(xl, y, xr - xl, color) end
        end
    end
end

-- The same even-odd fill as fillPolygon, but returned as a flat list of device-space rectangles
-- {x, y, w, h, x, y, w, h, ...}: consecutive scanlines with identical spans are merged into one
-- taller rectangle, so a rounded box costs a handful of native fills instead of one per row. The
-- edges are prepared once (lower end, x there, slope) and horizontal edges, which can never cross
-- a scanline centre, are dropped. Callers cache the result (see primitives.lua polygon).
local floor = math.floor
function lv1lua.core.polygonRuns(vertices)
    local n = #vertices / 2
    local runs = {}
    if n < 3 then return runs end

    local ya, yb, xa, slope, ne = {}, {}, {}, {}, 0
    local ymin, ymax = math.huge, -math.huge
    for i = 1, n do
        local x1, y1 = vertices[i * 2 - 1], vertices[i * 2]
        local j = i % n
        local x2, y2 = vertices[j * 2 + 1], vertices[j * 2 + 2]
        if y1 < ymin then ymin = y1 end
        if y1 > ymax then ymax = y1 end
        if y1 ~= y2 then
            ne = ne + 1
            if y1 < y2 then ya[ne], yb[ne], xa[ne], slope[ne] = y1, y2, x1, (x2 - x1) / (y2 - y1)
            else ya[ne], yb[ne], xa[ne], slope[ne] = y2, y1, x2, (x1 - x2) / (y1 - y2) end
        end
    end
    ymin, ymax = floor(ymin + 0.5), floor(ymax + 0.5)

    local xs = {}
    local prevL, prevW, prevRun, prevN, prevY = {}, {}, {}, 0, nil
    local curL, curW = {}, {}
    for y = ymin, ymax do
        local yc = y + 0.5
        local count = 0
        for e = 1, ne do
            if ya[e] <= yc and yb[e] > yc then
                count = count + 1
                xs[count] = xa[e] + (yc - ya[e]) * slope[e]
            end
        end
        for a = 2, count do
            local key, b = xs[a], a - 1
            while b >= 1 and xs[b] > key do xs[b + 1] = xs[b]; b = b - 1 end
            xs[b + 1] = key
        end
        local m = 0
        for k = 1, count - 1, 2 do
            local xl = floor(xs[k] + 0.5)
            local w = floor(xs[k + 1] + 0.5) - xl
            if w > 0 then m = m + 1; curL[m], curW[m] = xl, w end
        end
        local same = prevY == y - 1 and m == prevN
        if same then
            for k = 1, m do
                if curL[k] ~= prevL[k] or curW[k] ~= prevW[k] then same = false; break end
            end
        end
        if same then
            for k = 1, m do local r = prevRun[k]; runs[r + 3] = runs[r + 3] + 1 end
        else
            for k = 1, m do
                local r = #runs + 1
                runs[r], runs[r + 1], runs[r + 2], runs[r + 3] = curL[k], y, curW[k], 1
                prevRun[k] = r
                prevL[k], prevW[k] = curL[k], curW[k]
            end
            prevN = m
        end
        prevY = y
    end
    return runs
end
