local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
dofile("LOVE-WrapLua/OneLua/timer.lua")

-- ── getTime ──────────────────────────────────────────────────────
T.describe("love.timer.getTime", function()
    T.it("returns a non-negative number", function()
        local t = love.timer.getTime()
        T.istype(t, "number")
        T.ok(t >= 0, "time should be non-negative")
    end)
end)

-- ── getDelta ─────────────────────────────────────────────────────
T.describe("love.timer.getDelta", function()
    T.it("returns current value of global dt", function()
        dt = 0.016
        T.near(love.timer.getDelta(), 0.016)
        dt = 0
    end)
end)

-- ── getFPS ───────────────────────────────────────────────────────
T.describe("love.timer.getFPS", function()
    T.it("returns a positive integer when dt > 0", function()
        dt = 0.016
        local fps = love.timer.getFPS()
        T.ok(fps > 0, "fps should be positive")
        T.ok(fps == math.floor(fps), "fps should be integer")
        dt = 0
    end)

    T.it("returns 60 when dt == 0 (guard against division by zero)", function()
        dt = 0
        T.eq(love.timer.getFPS(), 60)
    end)
end)

-- ── getAverageDelta ──────────────────────────────────────────────
T.describe("love.timer.getAverageDelta", function()
    T.it("returns the current dt value", function()
        dt = 0.033
        T.near(love.timer.getAverageDelta(), 0.033)
        dt = 0
    end)
end)

-- ── sleep ────────────────────────────────────────────────────────
T.describe("love.timer.sleep", function()
    T.it("does not crash when called", function()
        local called_with = nil
        os.delay = function(ms) called_with = ms end
        love.timer.sleep(0.5)
        T.eq(called_with, 500)
        os.delay = function() end
    end)

    T.it("converts seconds to milliseconds correctly", function()
        local ms = nil
        os.delay = function(v) ms = v end
        love.timer.sleep(1)
        T.eq(ms, 1000)
        os.delay = function() end
    end)
end)

-- ── step ─────────────────────────────────────────────────────────
T.describe("love.timer.step", function()
    T.it("does not crash (no-op)", function()
        love.timer.step()
    end)
end)

io.write("\n=== love.timer (OneLua) ===\n")
return T.summary()
