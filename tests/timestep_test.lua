-- Fixed-timestep accumulator (FIX_PLAN T7.2).
--
-- Before this, every backend ran love.update only once its native timer had
-- passed 16 ms and then handed it the whole elapsed time: updates were capped
-- near 62 fps, dt jittered with the render rate, and anything under 16 ms per
-- frame was thrown away instead of accumulated. The suite drives the shared
-- accumulator directly, then each backend's lv1lua.update through its mock.

local T = dofile("tests/runner.lua")

local function fresh(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile("LOVE-WrapLua/core/loader.lua")
    lv1lua.load("LOVE-WrapLua/core/util.lua")
    lv1lua.load("LOVE-WrapLua/core/input.lua")
    lv1lua.load("LOVE-WrapLua/core/timestep.lua")
end

local STEP = 1 / 60

-- ── the accumulator itself ───────────────────────────────────────
T.describe("core.timestep accumulator", function()
    T.it("runs one update per slice at the configured rate", function()
        fresh("OneLua")
        local ts, n = lv1lua.core.newTimestep({ rate = 60 }), 0
        ts:advance(STEP, function() n = n + 1 end)
        T.eq(n, 1)
    end)

    T.it("hands love.update the fixed slice, not the frame time", function()
        fresh("OneLua")
        local ts, seen = lv1lua.core.newTimestep({ rate = 60 }), {}
        ts:advance(0.05, function(dt) seen[#seen + 1] = dt end)
        T.eq(#seen, 3)
        for i = 1, #seen do T.near(seen[i], STEP) end
    end)

    T.it("accumulates frames shorter than one slice instead of dropping them", function()
        fresh("OneLua")
        local ts, n = lv1lua.core.newTimestep({ rate = 60 }), 0
        -- Five 4 ms frames: the old >= 16 ms gate ran nothing at all.
        for _ = 1, 5 do ts:advance(0.004, function() n = n + 1 end) end
        T.eq(n, 1)
    end)

    T.it("keeps the update count on target over a second of uneven frames", function()
        fresh("OneLua")
        local ts, n = lv1lua.core.newTimestep({ rate = 60 }), 0
        local frames = { 0.004, 0.02, 0.011, 0.033, 0.007 }
        local elapsed, i = 0, 1
        while elapsed < 1 do
            local f = frames[i]
            ts:advance(f, function() n = n + 1 end)
            elapsed = elapsed + f
            i = i % #frames + 1
        end
        T.ok(math.abs(n - 60) <= 1, "want ~60 updates, got " .. n)
    end)

    T.it("is not capped at 62 fps: 200 fps frames still reach 60 updates", function()
        fresh("OneLua")
        local ts, n = lv1lua.core.newTimestep({ rate = 60 }), 0
        for _ = 1, 200 do ts:advance(0.005, function() n = n + 1 end) end
        T.ok(math.abs(n - 60) <= 1, "want ~60 updates, got " .. n)
    end)

    T.it("honours a non-default rate", function()
        fresh("OneLua")
        local ts, n = lv1lua.core.newTimestep({ rate = 30 }), 0
        ts:advance(1 / 30, function() n = n + 1 end)
        T.eq(n, 1)
        n = 0
        ts:advance(1 / 60, function() n = n + 1 end)
        T.eq(n, 0)
    end)

    T.it("clamps a long stall so the loop cannot spiral", function()
        fresh("OneLua")
        local ts, n = lv1lua.core.newTimestep({ rate = 60, maxSteps = 5 }), 0
        -- A 5 second stall (loading, sleep/resume) would be 300 catch-up steps.
        ts:advance(5, function() n = n + 1 end)
        T.eq(n, 5)
        -- The clamp must not leave a backlog behind either.
        n = 0
        ts:advance(0, function() n = n + 1 end)
        T.eq(n, 0)
    end)

    T.it("treats a missing elapsed as one slice (PS3 has no timer)", function()
        fresh("PS3")
        local ts, n = lv1lua.core.newTimestep({ rate = 60 }), 0
        ts:advance(nil, function() n = n + 1 end)
        T.eq(n, 1)
    end)

    T.it("ignores a negative elapsed from a reset native timer", function()
        fresh("OneLua")
        local ts, n = lv1lua.core.newTimestep({ rate = 60 }), 0
        ts:advance(-3, function() n = n + 1 end)
        T.eq(n, 0)
    end)

    T.it("reports the interpolation alpha of the leftover accumulator", function()
        fresh("OneLua")
        local ts = lv1lua.core.newTimestep({ rate = 60 })
        ts:advance(STEP * 1.5, function() end)
        T.near(ts.alpha, 0.5, 1e-3)
    end)

    T.it("variable mode passes the real frame time through, once", function()
        fresh("OneLua")
        local ts, seen = lv1lua.core.newTimestep({ rate = "variable" }), {}
        ts:advance(0.05, function(dt) seen[#seen + 1] = dt end)
        T.eq(#seen, 1)
        T.near(seen[1], 0.05)
    end)

    T.it("reads the rate from lv1luaconf.updaterate", function()
        fresh("OneLua")
        lv1luaconf.updaterate = 30
        local ts = lv1lua.core.newTimestep()
        T.near(ts.step, 1 / 30)
        lv1luaconf.updaterate = nil
    end)
end)

-- ── frame statistics ─────────────────────────────────────────────
T.describe("core.timestep frame statistics", function()
    T.it("getFPS averages real frame time, not the update slice", function()
        fresh("OneLua")
        for _ = 1, 40 do lv1lua.core.step(0.01) end
        T.eq(lv1lua.core.getFPS(), 100)
    end)

    T.it("getAverageDelta is the mean real frame time", function()
        fresh("OneLua")
        for _ = 1, 10 do lv1lua.core.step(0.02) end
        T.near(lv1lua.core.getAverageDelta(), 0.02, 1e-6)
    end)

    T.it("exposes the real frame delta beside the fixed update dt", function()
        fresh("OneLua")
        lv1lua.core.step(0.05)
        T.near(lv1lua.frameDelta, 0.05)
        T.near(lv1lua.dt, STEP)
    end)

    T.it("getFPS is 60 before any frame has been timed", function()
        fresh("OneLua")
        T.eq(lv1lua.core.getFPS(), 60)
    end)
end)

-- ── the shared driver ────────────────────────────────────────────
T.describe("core.timestep driver", function()
    T.it("lv1lua.core.step calls love.update with the fixed slice", function()
        fresh("OneLua")
        local seen = {}
        love.update = function(dt) seen[#seen + 1] = dt end
        lv1lua.core.step(0.05)
        T.eq(#seen, 3)
        T.near(seen[1], STEP)
        love.update = nil
    end)

    T.it("does not error when the game defines no love.update", function()
        fresh("OneLua")
        love.update = nil
        lv1lua.core.step(0.05)
        T.ok(true)
    end)
end)

-- ── backend wiring ───────────────────────────────────────────────
-- Each backend reads its own native timer and must feed the accumulator.
local function loadBackend(mode)
    fresh(mode)
    lv1lua.load("LOVE-WrapLua/core/config.lua")
    lv1lua.load("LOVE-WrapLua/core/modules.lua")
end

T.describe("backend loops drive the accumulator", function()
    T.it("OneLua: a 5 ms frame still advances the game (no 16 ms gate)", function()
        loadBackend("OneLua")
        local n = 0
        love.update = function() n = n + 1 end
        -- Four 5 ms frames: 20 ms accumulated, one slice due.
        for _ = 1, 4 do
            lv1lua.timer._elapsed = 5
            lv1lua.update()
        end
        T.eq(n, 1)
        love.update = nil
    end)

    T.it("OneLua: the native timer is reset every frame", function()
        loadBackend("OneLua")
        lv1lua.timer._elapsed = 5
        lv1lua.update()
        T.eq(lv1lua.timer._elapsed, 0)
    end)

    T.it("lpp-vita: a 5 ms frame still advances the game", function()
        loadBackend("lpp-vita")
        local n = 0
        love.update = function() n = n + 1 end
        for _ = 1, 4 do
            lv1lua.timer._t = 5
            lv1lua.update()
        end
        T.eq(n, 1)
        love.update = nil
    end)

    T.it("lpp-vita: the native timer is reset every frame", function()
        loadBackend("lpp-vita")
        lv1lua.timer._t = 5
        lv1lua.update()
        T.eq(lv1lua.timer._t, 0)
    end)

    T.it("PS3: one update per frame, at the fixed slice", function()
        loadBackend("PS3")
        local seen = {}
        love.update = function(dt) seen[#seen + 1] = dt end
        lv1lua.update()
        T.eq(#seen, 1)
        T.near(seen[1], STEP)
        love.update = nil
    end)

    T.it("PSP: a 5 ms frame still advances the game", function()
        loadBackend("PSP")
        local n = 0
        love.update = function() n = n + 1 end
        for _ = 1, 4 do
            lv1lua.timer._elapsed = 5
            lv1lua.update()
        end
        T.eq(n, 1)
        love.update = nil
    end)
end)

-- ── love.timer reads the same statistics ─────────────────────────
T.describe("love.timer over the accumulator", function()
    local function timerFor(mode)
        loadBackend(mode)
    end

    T.it("OneLua: getFPS follows the real frame rate", function()
        timerFor("OneLua")
        for _ = 1, 40 do lv1lua.core.step(0.01) end
        T.eq(love.timer.getFPS(), 100)
    end)

    T.it("lpp-vita: getAverageDelta is the mean frame time", function()
        timerFor("lpp-vita")
        for _ = 1, 10 do lv1lua.core.step(0.025) end
        T.near(love.timer.getAverageDelta(), 0.025, 1e-6)
    end)

    T.it("PS3: getDelta is the fixed slice the update ran with", function()
        timerFor("PS3")
        lv1lua.core.step(0.05)
        T.near(love.timer.getDelta(), STEP)
    end)

    T.it("love.timer.step reports the last real frame delta", function()
        timerFor("OneLua")
        lv1lua.core.step(0.033)
        T.near(love.timer.step(), 0.033)
    end)
end)

return T.summary()
