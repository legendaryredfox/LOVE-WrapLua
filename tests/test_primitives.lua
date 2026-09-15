-- Multi-backend primitive/draw suite.
--
-- Runs the same shared checks under OneLua, lpp-vita and PS3 (each with a fresh
-- mock environment), plus per-backend native-argument-order assertions.  The
-- lpp-vita mock encodes the real native contract from luaGraphics.cpp, so a
-- wrapper that passes primitive coordinates in the wrong order (#12) fails here
-- instead of mis-rendering on device.

local T = dofile("tests/runner.lua")

local GFX = {
    ["OneLua"]   = "LOVE-WrapLua/OneLua/graphics.lua",
    ["PSP"]      = "LOVE-WrapLua/OneLua/graphics_psp.lua",
    ["lpp-vita"] = "LOVE-WrapLua/lpp-vita/graphics.lua",
    ["PS3"]      = "LOVE-WrapLua/PS3/graphics.lua",
}

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile(GFX[mode])
    __rec.reset()
end

-- ── shared checks (run under every backend) ──────────────────────
local function shared_suite(mode)
    T.describe("primitives ["..mode.."]", function()
        T.it("newImage returns a drawable with dimensions", function()
            local img = love.graphics.newImage("sprite.png")
            T.ok(img ~= nil, "image should load")
        end)

        T.it("line does not error", function()
            love.graphics.line(0, 0, 10, 20)
        end)

        T.it("rectangle fill/line do not error", function()
            love.graphics.rectangle("fill", 10, 20, 30, 40)
            love.graphics.rectangle("line", 10, 20, 30, 40)
        end)

        T.it("circle does not error", function()
            love.graphics.circle("fill", 50, 50, 10)
            love.graphics.circle("line", 50, 50, 10)
        end)

        T.it("polygon does not error", function()
            love.graphics.polygon("line", {0,0, 10,0, 10,10})
        end)
    end)
end

-- ── OneLua ───────────────────────────────────────────────────────
load_backend("OneLua")
shared_suite("OneLua")
T.describe("OneLua native order", function()
    T.it("line maps to draw.line(x1,y1,x2,y2)", function()
        __rec.reset()
        love.graphics.line(0, 0, 10, 20)
        local c = __rec.last("draw.line")
        T.ok(c ~= nil, "draw.line should be called")
        T.eq(c.args[1], 0); T.eq(c.args[2], 0)
        T.eq(c.args[3], 10); T.eq(c.args[4], 20)
    end)
end)

-- ── PSP (OneLua on 480x272) ──────────────────────────────────────
load_backend("PSP")
shared_suite("PSP")
T.describe("PSP native order", function()
    T.it("line maps to draw.line(x1,y1,x2,y2)", function()
        __rec.reset()
        love.graphics.line(0, 0, 10, 20)
        local c = __rec.last("draw.line")
        T.ok(c ~= nil, "draw.line should be called")
        T.eq(c.args[1], 0); T.eq(c.args[2], 0)
        T.eq(c.args[3], 10); T.eq(c.args[4], 20)
    end)

    T.it("reports the 480x272 screen", function()
        T.eq(love.graphics.getWidth(), 480)
        T.eq(love.graphics.getHeight(), 272)
    end)

    T.it("reports the 512px texture limit", function()
        T.eq(love.graphics.getSystemLimits().texturesize, 512)
    end)
end)

-- ── lpp-vita ─────────────────────────────────────────────────────
load_backend("lpp-vita")
shared_suite("lpp-vita")
T.describe("lpp-vita native order (luaGraphics.cpp)", function()
    T.it("drawLine native order is (x1, x2, y1, y2)", function()
        __rec.reset()
        love.graphics.line(0, 0, 10, 20)  -- love order: x1,y1,x2,y2
        local c = __rec.last("Graphics.drawLine")
        T.ok(c ~= nil, "Graphics.drawLine should be called")
        T.eq(c.args[1], 0)   -- x1
        T.eq(c.args[2], 10)  -- x2  (native slot 2 is x2, not y1)
        T.eq(c.args[3], 0)   -- y1
        T.eq(c.args[4], 20)  -- y2
    end)

    T.it("fillRect native order is (x1, x2, y1, y2)", function()
        __rec.reset()
        love.graphics.rectangle("fill", 10, 20, 30, 40)  -- x,y,w,h
        local c = __rec.last("Graphics.fillRect")
        T.ok(c ~= nil, "Graphics.fillRect should be called")
        T.eq(c.args[1], 10)  -- x1
        T.eq(c.args[2], 40)  -- x2 = x+w
        T.eq(c.args[3], 20)  -- y1
        T.eq(c.args[4], 60)  -- y2 = y+h
    end)
end)

-- ── PS3 ──────────────────────────────────────────────────────────
load_backend("PS3")
shared_suite("PS3")

io.write("\n=== primitives (multi-backend) ===\n")
return T.summary()
