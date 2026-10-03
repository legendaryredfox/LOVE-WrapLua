-- Primitives honour the transform stack (FIX_PLAN T5.2).
--
-- Images already followed push/translate/scale on OneLua and lpp-vita while
-- primitives followed only the scale (OneLua) or nothing at all (lpp-vita), so
-- a translated scene drew its sprites and its shapes in different places.
--
-- PSP and PS3 have no transform stack, so their primitives must stay exactly
-- where the game put them: that is asserted too, so a later "fix" cannot
-- quietly start offsetting them.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    love.graphics.origin()
    __rec.reset()
end

-- ── OneLua (draw.* takes LOVE's plain argument order) ────────────
load_backend("OneLua")
T.describe("primitives follow the transform [OneLua]", function()
    T.it("translate shifts a filled rectangle", function()
        love.graphics.origin()
        love.graphics.translate(50, 20)
        __rec.reset()
        love.graphics.rectangle("fill", 10, 10, 30, 40)
        local a = __rec.last("draw.fillrect").args
        T.eq(a[1], 60)
        T.eq(a[2], 30)
        T.eq(a[3], 30)
        T.eq(a[4], 40)
        love.graphics.origin()
    end)

    T.it("scale still reaches the rectangle's size", function()
        love.graphics.origin()
        love.graphics.scale(2, 3)
        __rec.reset()
        love.graphics.rectangle("fill", 0, 0, 10, 10)
        local a = __rec.last("draw.fillrect").args
        T.eq(a[3], 20)
        T.eq(a[4], 30)
        love.graphics.origin()
    end)

    T.it("translate and scale compose for a rectangle", function()
        love.graphics.origin()
        love.graphics.scale(2, 2)
        love.graphics.translate(10, 5)
        __rec.reset()
        love.graphics.rectangle("fill", 1, 1, 4, 4)
        local a = __rec.last("draw.fillrect").args
        -- offset = scale * translate = (20, 10); point = offset + scale * local
        T.eq(a[1], 22)
        T.eq(a[2], 12)
        T.eq(a[3], 8)
        T.eq(a[4], 8)
        love.graphics.origin()
    end)

    T.it("translate shifts a line's endpoints", function()
        love.graphics.origin()
        love.graphics.translate(7, 3)
        __rec.reset()
        love.graphics.line(0, 0, 10, 10)
        local a = __rec.last("draw.line").args
        T.eq(a[1], 7)
        T.eq(a[2], 3)
        T.eq(a[3], 17)
        T.eq(a[4], 13)
        love.graphics.origin()
    end)

    T.it("translate shifts a filled circle's centre", function()
        love.graphics.origin()
        love.graphics.translate(100, 200)
        __rec.reset()
        love.graphics.circle("fill", 10, 10, 5)
        local a = __rec.last("draw.circle").args
        T.eq(a[1], 110)
        T.eq(a[2], 210)
        T.eq(a[3], 5)
        love.graphics.origin()
    end)

    T.it("a scaled circle scales its radius once, not twice", function()
        love.graphics.origin()
        love.graphics.scale(2, 2)
        __rec.reset()
        love.graphics.circle("fill", 0, 0, 5)
        T.eq(__rec.last("draw.circle").args[3], 10)
        love.graphics.origin()
    end)

    T.it("translate shifts polygon vertices", function()
        love.graphics.origin()
        love.graphics.translate(5, 5)
        __rec.reset()
        love.graphics.polygon("line", {0, 0, 10, 0, 10, 10})
        local first = __rec.all("draw.line")[1].args
        T.eq(first[1], 5)
        T.eq(first[2], 5)
        T.eq(first[3], 15)
        T.eq(first[4], 5)
        love.graphics.origin()
    end)

    T.it("translate shifts points", function()
        love.graphics.origin()
        love.graphics.translate(4, 6)
        __rec.reset()
        love.graphics.points(1, 1)
        local a = __rec.last("draw.fillrect").args
        T.eq(a[1], 5)
        T.eq(a[2], 7)
        love.graphics.origin()
    end)

    T.it("origin puts primitives back where the game asked", function()
        love.graphics.origin()
        __rec.reset()
        love.graphics.rectangle("fill", 10, 10, 30, 40)
        local a = __rec.last("draw.fillrect").args
        T.eq(a[1], 10)
        T.eq(a[2], 10)
    end)
end)

-- ── lpp-vita (native order is x1, x2, y1, y2) ────────────────────
load_backend("lpp-vita")
T.describe("primitives follow the transform [lpp-vita]", function()
    T.it("translate shifts a filled rectangle, in native arg order", function()
        love.graphics.origin()
        love.graphics.translate(50, 20)
        __rec.reset()
        love.graphics.rectangle("fill", 10, 10, 30, 40)
        local a = __rec.last("Graphics.fillRect").args
        T.eq(a[1], 60)   -- x1
        T.eq(a[2], 90)   -- x2 = x1 + w
        T.eq(a[3], 30)   -- y1
        T.eq(a[4], 70)   -- y2 = y1 + h
        love.graphics.origin()
    end)

    T.it("scale reaches the rectangle's size", function()
        love.graphics.origin()
        love.graphics.scale(2, 3)
        __rec.reset()
        love.graphics.rectangle("fill", 0, 0, 10, 10)
        local a = __rec.last("Graphics.fillRect").args
        T.eq(a[2] - a[1], 20)
        T.eq(a[4] - a[3], 30)
        love.graphics.origin()
    end)

    T.it("translate shifts a line", function()
        love.graphics.origin()
        love.graphics.translate(7, 3)
        __rec.reset()
        love.graphics.line(0, 0, 10, 10)
        local a = __rec.last("Graphics.drawLine").args
        T.eq(a[1], 7)    -- x1
        T.eq(a[2], 17)   -- x2
        T.eq(a[3], 3)    -- y1
        T.eq(a[4], 13)   -- y2
        love.graphics.origin()
    end)

    T.it("translate shifts a filled circle's centre", function()
        love.graphics.origin()
        love.graphics.translate(100, 200)
        __rec.reset()
        love.graphics.circle("fill", 10, 10, 5)
        local a = __rec.last("Graphics.fillCircle").args
        T.eq(a[1], 110)
        T.eq(a[2], 210)
        T.eq(a[3], 5)
        love.graphics.origin()
    end)
end)

-- ── PSP: no transform stack, coordinates must pass through ───────
load_backend("PSP")
T.describe("primitives ignore transforms [PSP]", function()
    T.it("translate is a no-op for a rectangle", function()
        love.graphics.translate(50, 20)
        __rec.reset()
        love.graphics.rectangle("fill", 10, 10, 30, 40)
        local a = __rec.last("draw.fillrect").args
        T.eq(a[1], 10)
        T.eq(a[2], 10)
        T.eq(a[3], 30)
        T.eq(a[4], 40)
    end)
end)

io.write("\n=== primitives vs transform stack ===\n")
return T.summary()
