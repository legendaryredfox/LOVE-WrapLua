-- ParticleSystem size, colour and rotation curves, seen through the draw calls the system replays.

local T = dofile("tests/runner.lua")
__MODE = "PSP"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/OneLua/graphics_psp.lua")
local lg = love.graphics

local img = lg.newImage("sheet.png")
local W, H = img:getWidth(), img:getHeight()

local function system()
    local ps = lg.newParticleSystem(img, 100)
    ps:setPosition(10, 20)
    ps:setSpeed(0, 0)
    ps:setParticleLifetime(1, 1)
    return ps
end

-- Runs the system's draw with `love.graphics.draw` replaced by a recorder; each record keeps the draw
-- arguments and the colour that was set when it was issued.
local function replay(ps)
    local calls, real = {}, lg.draw
    lg.draw = function(drawable, x, y, r, sx, sy, ox, oy)
        local cr, cg, cb, ca = lg.getColor()
        calls[#calls + 1] = { x = x, y = y, r = r, sx = sx, sy = sy, ox = ox, oy = oy,
                              cr = cr, cg = cg, cb = cb, ca = ca }
    end
    local ok, err = pcall(ps._draw, ps, 0, 0, 0, 1, 1, 0, 0)
    lg.draw = real
    if not ok then error(err, 0) end
    return calls
end

T.describe("ParticleSystem curves", function()
    T.it("without curves a particle is a plain draw at its position", function()
        lg.origin()
        local ps = system()
        ps:emit(1)
        local c = replay(ps)[1]
        T.eq(c.x, 10); T.eq(c.y, 20)
        T.ok(c.r == nil or c.r == 0)
    end)

    T.it("setSizes scales a particle along its life and draws it about its centre", function()
        lg.origin()
        local ps = system()
        ps:setSizes(1, 3)
        ps:emit(1)
        local c = replay(ps)[1]
        T.near(c.sx, 1, 1e-9); T.near(c.sy, 1, 1e-9)
        T.near(c.ox, W / 2, 1e-9); T.near(c.oy, H / 2, 1e-9)
        ps:update(0.5)
        c = replay(ps)[1]
        T.near(c.sx, 2, 1e-9); T.near(c.sy, 2, 1e-9)
    end)

    T.it("three sizes interpolate piecewise", function()
        lg.origin()
        local ps = system()
        ps:setSizes(0, 2, 0)
        ps:emit(1)
        ps:update(0.25)
        T.near(replay(ps)[1].sx, 1, 1e-9)
        ps:update(0.25)
        T.near(replay(ps)[1].sx, 2, 1e-9)
        ps:update(0.25)
        T.near(replay(ps)[1].sx, 1, 1e-9)
    end)

    T.it("getSizes returns what was set", function()
        local ps = system()
        ps:setSizes(1, 2, 3)
        local a, b, c = ps:getSizes()
        T.eq(a, 1); T.eq(b, 2); T.eq(c, 3)
    end)

    T.it("size variation only ever shrinks a particle", function()
        lg.origin()
        local ps = system()
        ps:setSizes(2)
        ps:setSizeVariation(0.5)
        ps:emit(20)
        for _, c in ipairs(replay(ps)) do
            T.ok(c.sx <= 2 + 1e-9 and c.sx >= 1 - 1e-9, "size " .. c.sx .. " outside 1..2")
        end
        T.eq(ps:getSizeVariation(), 0.5)
    end)

    T.it("setColors fades the colour along the life and restores the current colour", function()
        lg.origin()
        lg.setColor(1, 1, 1, 1)
        local ps = system()
        ps:setColors(1, 0, 0, 1, 0, 0, 1, 0)
        ps:emit(1)
        ps:update(0.5)
        local c = replay(ps)[1]
        T.near(c.cr, 0.5, 1e-9); T.near(c.cg, 0, 1e-9)
        T.near(c.cb, 0.5, 1e-9); T.near(c.ca, 0.5, 1e-9)
        local r, g, b, a = lg.getColor()
        T.eq(r, 1); T.eq(g, 1); T.eq(b, 1); T.eq(a, 1)
    end)

    T.it("the particle colour multiplies the current colour", function()
        lg.origin()
        lg.setColor(0.5, 1, 1, 0.5)
        local ps = system()
        ps:setColors(1, 1, 1, 1)
        ps:emit(1)
        local c = replay(ps)[1]
        T.near(c.cr, 0.5, 1e-9); T.near(c.ca, 0.5, 1e-9)
        lg.setColor(1, 1, 1, 1)
    end)

    T.it("setColors takes tables as well as numbers, and 3-number tables are opaque", function()
        lg.origin()
        lg.setColor(1, 1, 1, 1)
        local ps = system()
        ps:setColors({ 1, 0, 0 }, { 0, 1, 0, 0 })
        ps:emit(1)
        local c = replay(ps)[1]
        T.near(c.cr, 1, 1e-9); T.near(c.ca, 1, 1e-9)
        ps:update(1 - 1e-9)
        c = replay(ps)[1]
        T.near(c.cg, 1, 1e-6); T.near(c.ca, 0, 1e-6)
    end)

    T.it("setRotation sets the starting angle", function()
        lg.origin()
        local ps = system()
        ps:setRotation(1.5, 1.5)
        ps:emit(1)
        T.near(replay(ps)[1].r, 1.5, 1e-9)
    end)

    T.it("setSpin turns a particle by the spin times the time lived", function()
        lg.origin()
        local ps = system()
        ps:setRotation(0, 0)
        ps:setSpin(2, 2)
        ps:emit(1)
        ps:update(0.5)
        T.near(replay(ps)[1].r, 1, 1e-9)
    end)

    T.it("a system with a curve draws every live particle", function()
        lg.origin()
        local ps = system()
        ps:setSizes(1, 2)
        ps:setColors(1, 1, 1, 1, 1, 1, 1, 0)
        ps:emit(5)
        T.eq(#replay(ps), 5)
    end)
end)

return T.summary()
