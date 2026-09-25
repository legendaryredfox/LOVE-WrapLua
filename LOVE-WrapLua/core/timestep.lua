-- Fixed-timestep accumulator, shared by every backend (FIX_PLAN T7.2).
--
-- Each backend used to gate love.update behind "has the native timer passed
-- 16 ms", then hand it the whole elapsed time. Three things followed: updates
-- could not exceed ~62 per second, anything under 16 ms was discarded instead
-- of carried over, and dt moved with the render rate so game logic ran at a
-- different speed on every backend. Here the measured frame time goes into an
-- accumulator and love.update is called in fixed slices, with the remainder
-- kept for the next frame.
--
-- Backends call lv1lua.core.step(elapsedSeconds) once per frame. A backend
-- with no timer at all (PS3) passes nil and gets exactly one slice.
--
-- Configuration (lv1luaconf, see core/config.lua):
--   updaterate    updates per second, default 60; "variable" restores LOVE's
--                 desktop behaviour of one update per frame with the real dt
--   maxframeskip  most slices one frame may run, default 5 (stall guard)

lv1lua.core = lv1lua.core or {}

local DEFAULT_RATE      = 60
local DEFAULT_MAX_STEPS = 5
local AVERAGE_WINDOW    = 30

local Timestep = {}
Timestep.__index = Timestep

local function configuredRate()
    local conf = rawget(_G, "lv1luaconf")
    local r = conf and conf.updaterate
    if r == "variable" then return r end
    r = tonumber(r)
    if not r or r <= 0 then return DEFAULT_RATE end
    return r
end

local function configuredMaxSteps()
    local conf = rawget(_G, "lv1luaconf")
    local n = tonumber(conf and conf.maxframeskip)
    if not n or n < 1 then return DEFAULT_MAX_STEPS end
    return math.floor(n)
end

-- Rolling mean of the real frame time; love.timer.getFPS reports the render
-- rate, which is no longer the same number as the update rate.
local function recordFrame(self, elapsed)
    self.frameDelta = elapsed
    local i = self.frameIndex % AVERAGE_WINDOW + 1
    self.frameIndex  = i
    self.frameTotal  = self.frameTotal - (self.frames[i] or 0) + elapsed
    self.frames[i]   = elapsed
    if self.frameCount < AVERAGE_WINDOW then
        self.frameCount = self.frameCount + 1
    end
end

-- Runs `fn(dt)` zero or more times and returns how many slices ran.
function Timestep:advance(elapsed, fn)
    elapsed = tonumber(elapsed) or self.step
    if elapsed < 0 then elapsed = 0 end
    recordFrame(self, elapsed)

    if self.variable then
        -- LOVE's desktop loop: one update per frame with the measured time,
        -- still clamped so a stall cannot hand the game a huge dt.
        local dt = elapsed
        if dt > self.maxFrame then dt = self.maxFrame end
        self.alpha = 0
        lv1lua.dt = dt
        if fn then fn(dt) end
        return 1
    end

    -- A long stall (loading, a sleep/resume cycle) would otherwise queue
    -- hundreds of catch-up slices, each one making the next frame later still.
    if elapsed > self.maxFrame then elapsed = self.maxFrame end

    self.accumulator = self.accumulator + elapsed

    local steps = 0
    while self.accumulator >= self.step and steps < self.maxSteps do
        self.accumulator = self.accumulator - self.step
        steps = steps + 1
        lv1lua.dt = self.step
        if fn then fn(self.step) end
    end

    -- Drop whatever the clamp could not run rather than carrying a debt.
    if self.accumulator >= self.step then self.accumulator = 0 end

    self.alpha = self.accumulator / self.step
    return steps
end

function Timestep:getFPS()
    if self.frameCount == 0 or self.frameTotal <= 0 then return DEFAULT_RATE end
    return math.floor(self.frameCount / self.frameTotal + 0.5)
end

function Timestep:getAverageDelta()
    if self.frameCount == 0 then return 0 end
    return self.frameTotal / self.frameCount
end

function lv1lua.core.newTimestep(opts)
    opts = opts or {}
    local rate = opts.rate or configuredRate()
    local variable = rate == "variable"
    local step = variable and (1 / DEFAULT_RATE) or (1 / rate)
    local maxSteps = opts.maxSteps or configuredMaxSteps()

    return setmetatable({
        step        = step,
        rate        = variable and DEFAULT_RATE or rate,
        variable    = variable,
        maxSteps    = maxSteps,
        maxFrame    = step * maxSteps,
        accumulator = 0,
        alpha       = 0,
        frames      = {},
        frameTotal  = 0,
        frameCount  = 0,
        frameIndex  = 0,
        frameDelta  = 0,
    }, Timestep)
end

lv1lua.timestep = lv1lua.core.newTimestep()
lv1lua.dt = lv1lua.dt or 0
lv1lua.frameDelta = lv1lua.frameDelta or 0

-- What each backend's whileloop calls, once per frame.
function lv1lua.core.step(elapsed)
    local ts = lv1lua.timestep
    local steps = ts:advance(elapsed, love.update)
    lv1lua.frameDelta = ts.frameDelta
    return steps
end

function lv1lua.core.getFPS()
    return lv1lua.timestep:getFPS()
end

function lv1lua.core.getAverageDelta()
    return lv1lua.timestep:getAverageDelta()
end
