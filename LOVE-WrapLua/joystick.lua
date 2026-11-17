love.joystick = {}

-- lv1lua.joystickState must be filled each frame by platform's updatecontrols:
-- { axes = {lx, ly, rx, ry, l2, r2},  -- -1..1
--   buttons = { [1]=bool, ... },        -- raw button indices
--   hats = { [1] = "c"|"u"|"d"|"l"|"r"|"lu"|"ld"|"ru"|"rd" } }

-- core/input.lua creates this table and fills buttons/hats each frame; keep
-- whatever is already there so a frame's state is not wiped at load time.
lv1lua.joystickState = lv1lua.joystickState or {
    axes    = {0, 0, 0, 0, 0, 0},
    buttons = {},
    hats    = {"c"},
}

-- Gamepad button name → raw button index mapping
local gamepadToBtn = {
    a            = 1,  b          = 2,
    x            = 3,  y          = 4,
    back         = 5,  guide      = 6,  start       = 7,
    leftstick    = 8,  rightstick = 9,
    leftshoulder = 10, rightshoulder = 11,
    dpup         = 12, dpdown     = 13,
    dpleft       = 14, dpright    = 15,
}

local Joystick = {}
Joystick.__index = Joystick

function Joystick:isConnected()   return true  end
function Joystick:isGamepad()     return true  end
function Joystick:getName()       return love._console_name .. " Controller" end
function Joystick:getID()         return 1, "controller_0" end
function Joystick:getAxisCount()  return 6  end
function Joystick:getButtonCount() return 15 end
function Joystick:getHatCount()   return 1  end

function Joystick:getAxis(n)
    return lv1lua.joystickState.axes[n] or 0
end

function Joystick:getAxes()
    local a = lv1lua.joystickState.axes
    return a[1] or 0, a[2] or 0, a[3] or 0, a[4] or 0, a[5] or 0, a[6] or 0
end

function Joystick:isDown(...)
    for i = 1, select('#', ...) do
        if lv1lua.joystickState.buttons[select(i, ...)] then return true end
    end
    return false
end

function Joystick:getHat(n)
    return lv1lua.joystickState.hats[n] or "c"
end

function Joystick:getGamepadAxis(axis)
    local a = lv1lua.joystickState.axes
    if axis == "leftx"        then return a[1] or 0 end
    if axis == "lefty"        then return a[2] or 0 end
    if axis == "rightx"       then return a[3] or 0 end
    if axis == "righty"       then return a[4] or 0 end
    if axis == "triggerleft"  then return a[5] or 0 end
    if axis == "triggerright" then return a[6] or 0 end
    return 0
end

function Joystick:isGamepadDown(...)
    for i = 1, select('#', ...) do
        local idx = gamepadToBtn[select(i, ...)]
        if idx and lv1lua.joystickState.buttons[idx] then return true end
    end
    return false
end

function Joystick:getGamepadMapping(input)
    local idx = gamepadToBtn[input]
    if idx then return "button", idx, "a" end
    return nil
end

-- A backend whose SDK can drive a motor sets lv1lua.rumble(strength) (0..255) before this module loads. The
-- motors there are one strength, so the larger of the two intensities is sent.
local vibration = { left = 0, right = 0, sent = 0, remaining = nil }

local function clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

local function applyVibration()
    local strength = math.floor(math.max(vibration.left, vibration.right) * 255 + 0.5)
    if strength == vibration.sent then return end
    vibration.sent = strength
    lv1lua.rumble(strength)
end

function Joystick:isVibrationSupported() return lv1lua.rumble ~= nil end

-- setVibration(left, right [, duration]); no arguments stops it. A duration is in seconds of frame time.
function Joystick:setVibration(left, right, duration)
    if not lv1lua.rumble then return false end
    vibration.left, vibration.right = clamp01(left), clamp01(right)
    vibration.remaining = (duration and duration > 0) and duration or nil
    applyVibration()
    return true
end

function Joystick:getVibration() return vibration.left, vibration.right end

lv1lua.core = lv1lua.core or {}
function lv1lua.core.tickVibration(elapsed)
    local remaining = vibration.remaining
    if not remaining then return end
    remaining = remaining - elapsed
    if remaining > 0 then vibration.remaining = remaining; return end
    vibration.left, vibration.right, vibration.remaining = 0, 0, nil
    applyVibration()
end

local _joystick = setmetatable({}, Joystick)

function love.joystick.getJoysticks()         return {_joystick} end
function love.joystick.getJoystickCount()     return 1 end
function love.joystick.loadGamepadMappings()  end
function love.joystick.saveGamepadMappings()  return "" end
function love.joystick.setGamepadMapping()    end
function love.joystick.getGamepadMappingString() return "" end
