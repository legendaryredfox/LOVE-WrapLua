-- polygonRuns (merged rectangles, cached by primitives.lua) must cover exactly the pixels the
-- per-scanline fillPolygon covers, for convex and concave shapes and across the cache paths.

local T = dofile("tests/runner.lua")
__MODE = "OneLua"
dofile("tests/setup.lua")
lv1lua.core = lv1lua.core or {}
dofile("LOVE-WrapLua/core/polyfill.lua")

local function pixelsFromSpans(v)
    local set = {}
    lv1lua.core.fillPolygon(v, function(x, y, w) for i = 0, w - 1 do set[(x + i) .. "," .. y] = true end end, 0)
    return set
end
local function pixelsFromRuns(v)
    local set, runs = {}, lv1lua.core.polygonRuns(v)
    for i = 1, #runs, 4 do
        for dy = 0, runs[i + 3] - 1 do for dx = 0, runs[i + 2] - 1 do set[(runs[i] + dx) .. "," .. (runs[i + 1] + dy)] = true end end
    end
    return set
end
local function same(a, b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

local shapes = {
    rect      = { 2, 3, 12, 3, 12, 9, 2, 9 },
    triangle  = { 0, 0, 20, 4, 6, 15 },
    star      = { 10, 0, 13, 7, 20, 7, 14, 12, 16, 20, 10, 15, 4, 20, 6, 12, 0, 7, 7, 7 },
    pixelbox  = { 5, 0, 15, 0, 15, 2, 17, 2, 17, 10, 15, 10, 15, 12, 5, 12, 5, 10, 3, 10, 3, 2, 5, 2 },
    fractional = { 0.4, 0.6, 9.7, 1.2, 8.3, 8.8, 1.1, 7.5 },
}

T.describe("polygonRuns", function()
    for name, v in pairs(shapes) do
        T.it(name .. " covers the same pixels as the scanline fill", function()
            T.ok(same(pixelsFromSpans(v), pixelsFromRuns(v)), name .. " differs")
        end)
    end
    T.it("merges identical consecutive scanlines", function()
        local runs = lv1lua.core.polygonRuns(shapes.rect)
        T.eq(#runs, 4)            -- one rectangle
        T.eq(runs[3], 10); T.eq(runs[4], 6)
    end)
    T.it("a degenerate polygon yields no runs", function()
        T.eq(#lv1lua.core.polygonRuns({ 1, 1, 5, 5 }), 0)
    end)
end)

-- the cache in primitives.lua, through love.graphics.polygon
__MODE = "OneLua"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/OneLua/graphics.lua")
T.describe("polygon fill cache", function()
    local function area()
        local a = 0
        for _, c in ipairs(__rec.all("draw.fillrect")) do a = a + c.args[3] * c.args[4] end
        return a
    end
    T.it("the same table drawn twice paints the same area; a changed vertex repaints", function()
        love.graphics.origin()
        local v = { 0, 0, 10, 0, 10, 10, 0, 10 }
        __rec.reset(); love.graphics.polygon("fill", v); local a1 = area()
        __rec.reset(); love.graphics.polygon("fill", v); T.eq(area(), a1)
        v[3] = 20; v[5] = 20                              -- widen to 20x10
        __rec.reset(); love.graphics.polygon("fill", v); T.ok(area() > a1, "edited polygon must be redrawn bigger")
    end)
    T.it("an integer translation moves the cached rectangles by the same amount", function()
        love.graphics.origin()
        local v = { 0, 0, 10, 0, 10, 10, 0, 10 }
        __rec.reset(); love.graphics.polygon("fill", v)
        local x1, y1 = __rec.last("draw.fillrect").args[1], __rec.last("draw.fillrect").args[2]
        love.graphics.push(); love.graphics.translate(7, 5)
        __rec.reset(); love.graphics.polygon("fill", v)
        love.graphics.pop()
        local c = __rec.last("draw.fillrect")
        T.eq(c.args[1], x1 + 7); T.eq(c.args[2], y1 + 5)
    end)
    T.it("a fractional translation rebuilds instead of shifting", function()
        love.graphics.origin()
        local v = { 0, 0, 10, 0, 10, 10, 0, 10 }
        love.graphics.polygon("fill", v)
        love.graphics.push(); love.graphics.translate(0.5, 0)
        __rec.reset(); love.graphics.polygon("fill", v)
        love.graphics.pop()
        local c = __rec.last("draw.fillrect")
        T.eq(c.args[1], 1)        -- 0.5 rounds to 1, not the cached 0
    end)
end)

io.write("\n=== polyfill runs ===\n")
return T.summary()
