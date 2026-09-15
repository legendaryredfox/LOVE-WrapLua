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

-- PSP images are raw native handles, so a scaling draw must copy instead of
-- resizing the shared source (#6).
T.describe("PSP draw does not mutate the source image", function()
    T.it("drawing sx=2 then sx=1 leaves source dimensions unchanged", function()
        local img = love.graphics.newImage("s.png")
        __rec.reset()
        love.graphics.draw(img, 0, 0, 0, 2, 2)
        love.graphics.draw(img, 0, 0, 0, 1, 1)
        T.eq(image.getrealw(img), 64)
        T.eq(image.getrealh(img), 64)
        T.eq(__rec.count("image.resize"), 0)
    end)

    T.it("the scaling draw blits a copy, not the source", function()
        local img = love.graphics.newImage("s.png")
        __rec.reset()
        love.graphics.draw(img, 0, 0, 0, 2, 2)
        local copy = __rec.last("image.copyscale")
        local blit = __rec.last("image.blit")
        T.ok(copy ~= nil, "should copy the source before scaling")
        T.eq(copy.args[2], 128)  -- 64 * 2
        T.eq(copy.args[3], 128)
        T.ok(blit.args[1] ~= img, "should blit the copy, not the source")
    end)

    T.it("an unscaled draw blits the source directly", function()
        local img = love.graphics.newImage("s.png")
        __rec.reset()
        love.graphics.draw(img, 10, 20)
        T.eq(__rec.count("image.copyscale"), 0)
        T.eq(__rec.last("image.blit").args[1], img)
    end)

    T.it("reuses the copy while the scale is unchanged", function()
        local img = love.graphics.newImage("s.png")
        __rec.reset()
        love.graphics.draw(img, 0, 0, 0, 2, 2)
        love.graphics.draw(img, 50, 0, 0, 2, 2)
        T.eq(__rec.count("image.copyscale"), 1)
        T.eq(__rec.count("image.blit"), 2)
    end)

    T.it("rebuilds the copy when the scale changes", function()
        local img = love.graphics.newImage("s.png")
        __rec.reset()
        love.graphics.draw(img, 0, 0, 0, 2, 2)
        love.graphics.draw(img, 0, 0, 0, 3, 3)
        T.eq(__rec.count("image.copyscale"), 2)
        T.eq(__rec.last("image.copyscale").args[2], 192)  -- 64 * 3
    end)

    T.it("a rot=0 draw after a rotated draw is upright", function()
        local img = love.graphics.newImage("s.png")
        love.graphics.draw(img, 0, 0, math.pi / 2)
        __rec.reset()
        love.graphics.draw(img, 0, 0, 0)
        local c = __rec.last("image.rotate")
        T.ok(c ~= nil, "rotation should be set on every draw")
        T.near(c.args[2], 0, 1e-6)
    end)

    T.it("a negative scale flips the copy and anchors the mirror", function()
        local img = love.graphics.newImage("s.png")
        __rec.reset()
        love.graphics.draw(img, 0, 0, 0, -1, 1)
        T.eq(__rec.count("image.fliph"), 1)
        T.eq(__rec.count("image.flipv"), 0)
        -- Mirrored around x=0, so the 64px image occupies [-64, 0].
        T.eq(__rec.last("image.blit").args[2], -64)
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
