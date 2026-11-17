-- Rounded rectangles, the polygon fill cache bound and its hit/miss counters.

local T = dofile("tests/runner.lua")

local function load_backend(mode, gfx)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(gfx)
    __rec.reset()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
end

local function covered()
    local set, n = {}, 0
    for _, c in ipairs(__rec.all("draw.fillrect")) do
        local x, y, w, h = c.args[1], c.args[2], c.args[3], c.args[4]
        for yy = y, y + h - 1 do
            for xx = x, x + w - 1 do
                if not set[xx .. "," .. yy] then set[xx .. "," .. yy] = true; n = n + 1 end
            end
        end
    end
    return set, n
end

load_backend("PSP", "LOVE-WrapLua/OneLua/graphics_psp.lua")

T.describe("rounded rectangle [PSP]", function()
    T.it("a plain fill is one rectangle", function()
        __rec.reset()
        love.graphics.rectangle("fill", 10, 10, 40, 20)
        T.eq(__rec.count("draw.fillrect"), 1)
    end)

    T.it("rx/ry cut the corners off a fill", function()
        __rec.reset()
        love.graphics.rectangle("fill", 10, 10, 40, 20, 8, 8)
        local set, n = covered()
        T.nok(set["10,10"], "top-left corner pixel is cut")
        T.nok(set["49,29"], "bottom-right corner pixel is cut")
        T.ok(set["30,10"] and set["10,20"], "edges are filled")
        T.ok(n < 40 * 20 and n > 40 * 20 - 4 * 8 * 8 / 2, "area between the box and the box minus the corners")
    end)

    T.it("ry defaults to rx and radii clamp to half the size", function()
        __rec.reset()
        love.graphics.rectangle("fill", 0, 0, 10, 10, 100)
        local set, n = covered()
        T.ok(n > 0 and n < 100)
        T.ok(set["5,0"] and set["0,5"], "a clamped radius leaves a circle touching the edge midpoints")
    end)

    T.it("a rounded outline draws lines, not a sharp box", function()
        __rec.reset()
        love.graphics.rectangle("line", 10, 10, 40, 20, 6)
        T.ok(__rec.count("draw.line") > 4)
    end)

    T.it("radius 0 keeps the sharp native path", function()
        __rec.reset()
        love.graphics.rectangle("line", 10, 10, 40, 20, 0)
        T.eq(__rec.count("draw.rect"), 1)
    end)

    T.it("a rounded fill moved by whole pixels reuses the cached runs", function()
        local before = lv1lua.core.polygonCacheStats().hit
        love.graphics.rectangle("fill", 10, 10, 40, 20, 8)
        love.graphics.rectangle("fill", 90, 50, 40, 20, 8)
        T.ok(lv1lua.core.polygonCacheStats().hit >= before + 1)
    end)
end)

T.describe("polygon cache [PSP]", function()
    T.it("counts a miss then a hit for the same vertex table", function()
        local s0 = lv1lua.core.polygonCacheStats()
        local m, h = s0.miss, s0.hit
        local tri = { 0, 0, 20, 4, 6, 15 }
        love.graphics.polygon("fill", tri)
        love.graphics.polygon("fill", tri)
        local s1 = lv1lua.core.polygonCacheStats()
        T.eq(s1.miss, m + 1)
        T.eq(s1.hit, h + 1)
    end)

    T.it("a sub-pixel drift reuses the cached runs and lands on the nearest pixel", function()
        love.graphics.origin()
        local tri = { 0, 0, 20, 4, 6, 15, 3, 9 }
        local st = lv1lua.core.polygonCacheStats()
        love.graphics.polygon("fill", tri)
        local hit0, miss0 = st.hit, st.miss
        local at = {}
        for _, dx in ipairs({ 0.2, 0.4, 0.6, 0.9 }) do
            love.graphics.push(); love.graphics.translate(dx, dx)
            __rec.reset(); love.graphics.polygon("fill", tri)
            love.graphics.pop()
            at[#at + 1] = __rec.all("draw.fillrect")[1].args[1]
        end
        T.eq(st.hit, hit0 + 4)
        T.eq(st.miss, miss0)
        T.ok(at[1] == at[2], "0.2 and 0.4 round to the same pixel")
        T.ok(at[3] == at[4] and at[3] == at[1] + 1, "0.6 and 0.9 round to the next one")
    end)

    T.it("a huge polygon is drawn but not kept", function()
        local pts, n = {}, 400
        for i = 0, n - 1 do
            local a = i / n * 2 * math.pi
            pts[#pts + 1] = 200 + 150 * math.cos(a) + (i % 2) * 3
            pts[#pts + 1] = 300 + 300 * math.sin(a)
        end
        local st = lv1lua.core.polygonCacheStats()
        local skipped0, hit0 = st.skipped, st.hit
        __rec.reset()
        love.graphics.polygon("fill", pts)
        T.ok(__rec.count("draw.fillrect") > 0, "still drawn")
        love.graphics.polygon("fill", pts)
        T.eq(st.skipped, skipped0 + 2)
        T.eq(st.hit, hit0)
    end)
end)

io.write("\n=== polygon cache ===\n")
return T.summary()
