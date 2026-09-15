-- Key edge detection, shared by the backends.
--
-- Console SDKs expose "is this button down right now", while LOVE games expect
-- one keypressed per press and one keyreleased per release. Each backend builds
-- a map of LOVE key name to down-state every frame and hands it to a tracker,
-- which turns that into edges (and optional key repeats).
--
-- No scancodes exist on these consoles, so the key name is passed as the
-- scancode too, matching love.keyboard.getScancodeFromKey here.

lv1lua.core  = lv1lua.core or {}
lv1lua.input = lv1lua.input or {}

-- love.keyboard.setKeyRepeat state. Off is LOVE's default.
lv1lua.input.keyRepeat = false

-- Roughly SDL's defaults, which is what desktop LOVE ends up with.
local REPEAT_DELAY    = 0.4
local REPEAT_INTERVAL = 0.05

local Tracker = {}
Tracker.__index = Tracker

-- Overridable for tests; by default these are the LOVE callbacks.
function Tracker:emitPress(key, isrepeat)
    if love.keypressed then love.keypressed(key, key, isrepeat) end
end

function Tracker:emitRelease(key)
    if love.keyreleased then love.keyreleased(key, key) end
end

function Tracker:isDown(key)
    return self.down[key] == true
end

local function _press(self, key)
    self.down[key]     = true
    self.timer[key]    = 0
    self.repeated[key] = false
    self:emitPress(key, false)
end

local function _release(self, key)
    self.down[key]     = nil
    self.timer[key]    = nil
    self.repeated[key] = nil
    self:emitRelease(key)
end

local function _holdRepeat(self, key, dt)
    if not lv1lua.input.keyRepeat then return end
    local timer = (self.timer[key] or 0) + dt
    -- The first repeat waits out the delay; later ones come at the interval.
    local threshold = self.repeated[key] and REPEAT_INTERVAL or REPEAT_DELAY
    if timer >= threshold then
        self.repeated[key] = true
        timer = 0
        self:emitPress(key, true)
    end
    self.timer[key] = timer
end

-- `held` maps key name to a truthy value while the button is down. Keys the
-- caller leaves out are treated as released, so a backend that stops reporting
-- a button cannot strand it in the down state.
function Tracker:update(held, dt)
    dt = dt or 0
    held = held or {}

    for key, isDown in pairs(held) do
        if isDown then
            if self.down[key] then
                _holdRepeat(self, key, dt)
            else
                _press(self, key)
            end
        elseif self.down[key] then
            _release(self, key)
        end
    end

    -- Release anything still marked down that this frame did not mention.
    local stale
    for key in pairs(self.down) do
        if held[key] == nil then
            stale = stale or {}
            stale[#stale + 1] = key
        end
    end
    if stale then
        for i = 1, #stale do _release(self, stale[i]) end
    end
end

function lv1lua.core.newKeyTracker()
    return setmetatable({
        down     = {},
        timer    = {},
        repeated = {},
    }, Tracker)
end

-- Owned here rather than in each backend's keyboard.lua, so the three copies
-- cannot drift.
function love.keyboard.setKeyRepeat(enable)
    lv1lua.input.keyRepeat = enable and true or false
end

function love.keyboard.hasKeyRepeat()
    return lv1lua.input.keyRepeat
end
