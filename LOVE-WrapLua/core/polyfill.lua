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
-- module stays free of any SDK dependency. (FIX_PLAN T4.2)

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
