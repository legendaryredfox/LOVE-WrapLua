-- SpriteBatch, ParticleSystem and Text keep their queued data in compact arrays and reuse tables; the
-- behaviour seen through the LOVE API must not change.

local T = dofile("tests/runner.lua")
__MODE = "PSP"
dofile("tests/setup.lua")
dofile("LOVE-WrapLua/OneLua/graphics_psp.lua")
local lg = love.graphics

local function blits() return __rec.all("image.blit") end

-- LuaJIT counts compiled-trace and snapshot memory in collectgarbage("count"), so byte budgets are only
-- asserted on PUC Lua (even love.graphics.push/pop shows 120 bytes per call under LuaJIT).
local function budget(name, fn)
    T.it(name, function() if not jit then fn() end end)
end

-- The mock records every native call in a table; measure allocation with the recorder off.
local function quiet(fn)
    local log = __rec.log
    __rec.log = function() end
    local ok, err = pcall(fn)
    __rec.log = log
    if not ok then error(err, 0) end
end

T.describe("SpriteBatch", function()
    local img = lg.newImage("sheet.png")
    local q1 = lg.newQuad(0, 0, 8, 8, img)
    local q2 = lg.newQuad(16, 16, 8, 8, img)

    T.it("add returns consecutive ids and getCount follows", function()
        local sb = lg.newSpriteBatch(img, 10)
        T.eq(sb:add(q1, 1, 2), 1)
        T.eq(sb:add(10, 20), 2)
        T.eq(sb:add(q2, 3, 4), 3)
        T.eq(sb:getCount(), 3)
    end)

    T.it("draw replays every sprite in order, quad or not", function()
        lg.origin()
        local sb = lg.newSpriteBatch(img, 10)
        sb:add(q1, 10, 20)
        sb:add(50, 60)
        sb:add(q2, 30, 40)
        __rec.reset()
        lg.draw(sb, 100, 0)
        local b = blits()
        T.eq(#b, 3)
        T.eq(b[1].args[2], 110); T.eq(b[1].args[3], 20); T.eq(b[1].args[4], 0)    -- quad 1 source x
        T.eq(b[2].args[2], 150); T.eq(b[2].args[3], 60)                            -- whole image
        T.eq(b[3].args[2], 130); T.eq(b[3].args[4], 16)                            -- quad 2 source x
    end)

    T.it("a sprite with no position draws at the origin", function()
        lg.origin()
        local sb = lg.newSpriteBatch(img, 4)
        sb:add(q1)
        __rec.reset()
        lg.draw(sb, 7, 9)
        T.eq(blits()[1].args[2], 7); T.eq(blits()[1].args[3], 9)
    end)

    T.it("scale and origin arguments reach the draw", function()
        lg.origin()
        local sb = lg.newSpriteBatch(img, 4)
        sb:add(q1, 100, 100, 0, 1, 1, 4, 2)
        __rec.reset()
        lg.draw(sb, 0, 0)
        T.eq(blits()[1].args[2], 96); T.eq(blits()[1].args[3], 98)
    end)

    T.it("set replaces a sprite, also from a quad to a plain image and back", function()
        lg.origin()
        local sb = lg.newSpriteBatch(img, 4)
        local id = sb:add(q1, 1, 1)
        sb:set(id, 40, 50)
        __rec.reset()
        lg.draw(sb, 0, 0)
        T.eq(blits()[1].args[2], 40)
        T.eq(#blits(), 1)
        sb:set(id, q2, 5, 6)
        __rec.reset()
        lg.draw(sb, 0, 0)
        T.eq(blits()[1].args[2], 5); T.eq(blits()[1].args[4], 16)
    end)

    T.it("set on an id that does not exist does nothing", function()
        local sb = lg.newSpriteBatch(img, 4)
        sb:set(3, q1, 1, 1)
        T.eq(sb:getCount(), 0)
    end)

    T.it("clear empties the batch and ids start again", function()
        local sb = lg.newSpriteBatch(img, 4)
        sb:add(q1, 1, 1); sb:add(q1, 2, 2)
        sb:clear()
        T.eq(sb:getCount(), 0)
        T.eq(sb:add(q1, 3, 3), 1)
        __rec.reset()
        lg.draw(sb, 0, 0)
        T.eq(#blits(), 1)
    end)

    T.it("a cleared batch draws nothing and leaves the transform stack balanced", function()
        lg.origin()
        local sb = lg.newSpriteBatch(img, 4)
        sb:add(q1, 1, 1)
        sb:clear()
        __rec.reset()
        lg.draw(sb, 100, 100)
        T.eq(#blits(), 0)
        local q = lg.newQuad(0, 0, 4, 4, img)
        lg.draw(img, q, 1, 1)
        T.eq(blits()[1].args[2], 1)
    end)

    T.it("an error in the replay still pops the transform", function()
        lg.origin()
        local sb = lg.newSpriteBatch(img, 4)
        sb:add(q1, 1, 1)
        local real = lg.draw
        lg.draw = function() error("boom") end
        local ok = pcall(real, sb, 50, 50)
        lg.draw = real
        T.nok(ok)
        __rec.reset()
        lg.draw(img, 3, 3)
        T.eq(blits()[1].args[2], 3)
    end)

    T.it("getImage, setColor and getColor", function()
        local sb = lg.newSpriteBatch(img, 4)
        T.ok(sb:getImage() == img)
        T.eq(sb:getColor(), nil)
        sb:setColor(0.1, 0.2, 0.3, 0.4)
        local r, g, b, a = sb:getColor()
        T.near(r, 0.1, 1e-9); T.near(a, 0.4, 1e-9)
    end)

    budget("adding does not allocate a table per sprite", function()
        local sb = lg.newSpriteBatch(img, 400)
        for i = 1, 20 do sb:add(q1, i, i) end
        sb:clear()
        collectgarbage(); collectgarbage("stop")
        local before = collectgarbage("count")
        for i = 1, 200 do sb:add(q1, i, i) end
        local grew = (collectgarbage("count") - before) * 1024
        collectgarbage("restart")
        T.ok(grew < 200 * 200, "allocated " .. grew .. " bytes for 200 sprites")
    end)

    budget("drawing a batch does not allocate a closure each time", function()
        local sb = lg.newSpriteBatch(img, 4)
        sb:add(q1, 1, 1)
        for _ = 1, 300 do lg.draw(sb, 0, 0) end
        local grew
        quiet(function()
            collectgarbage(); collectgarbage("stop")
            local before = collectgarbage("count")
            for _ = 1, 50 do lg.draw(sb, 0, 0) end
            grew = (collectgarbage("count") - before) * 1024
            collectgarbage("restart")
        end)
        T.ok(grew < 50 * 40, "allocated " .. grew .. " bytes in 50 draws")
    end)
end)

T.describe("ParticleSystem", function()
    local img = lg.newImage("sheet.png")

    local function system()
        local ps = lg.newParticleSystem(img, 100)
        ps:setPosition(10, 20)
        ps:setSpeed(0, 0)
        ps:setParticleLifetime(1, 1)
        return ps
    end

    T.it("emit adds particles at the emitter position, draw replays them", function()
        lg.origin()
        local ps = system()
        ps:emit(3)
        T.eq(ps:getCount(), 3)
        __rec.reset()
        lg.draw(ps, 0, 0)
        T.eq(#blits(), 3)
        T.eq(blits()[1].args[2], 10); T.eq(blits()[1].args[3], 20)
    end)

    T.it("update moves particles by velocity and drops the ones past their lifetime", function()
        lg.origin()
        local ps = lg.newParticleSystem(img, 100)
        ps:setPosition(0, 0)
        ps:setDirection(0); ps:setSpread(0)
        ps:setSpeed(10, 10)
        ps:setParticleLifetime(1, 1)
        ps:emit(2)
        ps:update(0.5)
        T.eq(ps:getCount(), 2)
        __rec.reset()
        lg.draw(ps, 0, 0)
        T.near(blits()[1].args[2], 5, 1e-6)
        ps:update(0.6)
        T.eq(ps:getCount(), 0)
    end)

    T.it("survivors keep their order when an earlier one dies", function()
        lg.origin()
        local ps = lg.newParticleSystem(img, 100)
        ps:setDirection(0); ps:setSpread(0); ps:setSpeed(0, 0)
        ps:setPosition(1, 0); ps:setParticleLifetime(0.4, 0.4); ps:emit(1)
        ps:update(0.3)
        ps:setPosition(2, 0); ps:setParticleLifetime(1, 1); ps:emit(1)
        ps:setPosition(3, 0); ps:emit(1)
        ps:update(0.2)
        T.eq(ps:getCount(), 2)
        __rec.reset()
        lg.draw(ps, 0, 0)
        T.eq(blits()[1].args[2], 2); T.eq(blits()[2].args[2], 3)
    end)

    T.it("an emitting system creates particles at its rate", function()
        local ps = system()
        ps:setEmissionRate(60)
        ps:start()
        ps:update(0.5)
        T.eq(ps:getCount(), 30)
    end)

    T.it("reset drops every particle and the system can emit again", function()
        local ps = system()
        ps:emit(5); ps:reset()
        T.eq(ps:getCount(), 0)
        ps:emit(2)
        T.eq(ps:getCount(), 2)
    end)

    budget("a steady system allocates almost nothing per update once warm", function()
        local ps = lg.newParticleSystem(img, 400)
        ps:setPosition(0, 0); ps:setSpeed(5, 5); ps:setParticleLifetime(100, 100)
        ps:emit(200)
        ps:update(1 / 60); ps:update(1 / 60)
        collectgarbage(); collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 10 do ps:update(1 / 60) end
        local grew = (collectgarbage("count") - before) * 1024
        collectgarbage("restart")
        T.ok(grew < 10 * 160, "allocated " .. grew .. " bytes in 10 updates")
    end)

    budget("particles that died are reused by later emits", function()
        local ps = lg.newParticleSystem(img, 400)
        ps:setPosition(0, 0); ps:setSpeed(0, 0); ps:setParticleLifetime(0.1, 0.1)
        ps:emit(100); ps:update(0.2)
        T.eq(ps:getCount(), 0)
        collectgarbage(); collectgarbage("stop")
        local before = collectgarbage("count")
        ps:emit(100)
        local grew = (collectgarbage("count") - before) * 1024
        collectgarbage("restart")
        T.ok(grew < 100 * 40, "allocated " .. grew .. " bytes for 100 reused particles")
    end)
end)

T.describe("Text", function()
    T.it("draws its strings in order through print", function()
        lg.origin()
        local font = lg.newFont(12)
        local t = lg.newText(font, "")
        t:add("one", 0, 0); t:add("two", 0, 12)
        __rec.reset()
        lg.draw(t, 5, 5)
        T.eq(__rec.count("screen.print"), 2)
    end)

    budget("drawing Text restores the font and does not allocate a closure each time", function()
        local font = lg.newFont(12)
        local t = lg.newText(font, "hi")
        local prev = lv1lua.current.font
        for _ = 1, 300 do lg.draw(t, 0, 0) end
        T.ok(lv1lua.current.font == prev)
        local grew
        quiet(function()
            collectgarbage(); collectgarbage("stop")
            local before = collectgarbage("count")
            for _ = 1, 50 do lg.draw(t, 0, 0) end
            grew = (collectgarbage("count") - before) * 1024
            collectgarbage("restart")
        end)
        T.ok(grew < 50 * 40, "allocated " .. grew .. " bytes in 50 draws")
    end)
end)

io.write("\n=== compact batches ===\n")
return T.summary()
