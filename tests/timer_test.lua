local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
dofile("LOVE-WrapLua/core/loader.lua")
lv1lua.load("LOVE-WrapLua/core/timestep.lua")
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
    T.it("returns the frame delta the main loop stored on lv1lua.dt", function()
        lv1lua.dt = 0.016
        T.near(love.timer.getDelta(), 0.016)
        lv1lua.dt = 0
    end)
end)

-- ── getFPS ───────────────────────────────────────────────────────
-- Since T7.2 the render rate is measured by the accumulator instead of being
-- inferred from the update dt, which is now fixed.
T.describe("love.timer.getFPS", function()
    T.it("returns a positive integer once frames have been timed", function()
        for _ = 1, 10 do lv1lua.core.step(0.02) end
        local fps = love.timer.getFPS()
        T.ok(fps > 0, "fps should be positive")
        T.ok(fps == math.floor(fps), "fps should be integer")
    end)

    T.it("returns 60 before any frame has been timed", function()
        lv1lua.timestep = lv1lua.core.newTimestep()
        T.eq(love.timer.getFPS(), 60)
    end)
end)

-- ── getAverageDelta ──────────────────────────────────────────────
T.describe("love.timer.getAverageDelta", function()
    T.it("returns the mean measured frame time", function()
        lv1lua.timestep = lv1lua.core.newTimestep()
        for _ = 1, 10 do lv1lua.core.step(0.033) end
        T.near(love.timer.getAverageDelta(), 0.033, 1e-9)
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
    T.it("reports the last frame time the main loop measured", function()
        lv1lua.core.step(0.021)
        T.near(love.timer.step(), 0.021)
    end)
end)

io.write("\n=== love.timer (OneLua) ===\n")
return T.summary()
