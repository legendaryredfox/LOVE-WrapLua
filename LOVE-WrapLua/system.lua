-- love.system (FIX_PLAN T6.1).
--
-- Shared module: it reads lv1lua.* and the capability table, and touches an SDK
-- global only through a guarded probe, because the same file runs on four SDKs
-- and none of them is required to expose a given call. Anything the platform
-- cannot answer returns LOVE's documented "I do not know" value instead of
-- erroring: a game asking for the battery level must not take a console down.

if lv1lua.isPSP then
    love._console_name = "PSP"
elseif lv1lua.mode == "PS3" then
    love._console_name = "PS3"
else
    love._console_name = "Vita"
end

local function caps()
    local c = love._backend or lv1lua.core.capabilities(lv1lua.mode)
    return c.system or {}
end

-- A native call only if the SDK really has it: a missing binding is the normal
-- case here, not an error.
local function native(tbl, name)
    if type(tbl) ~= "table" then return nil end
    local fn = tbl[name]
    if type(fn) == "function" then return fn end
    return nil
end

function love.system.getOS()
    return "LOVE-WrapLua"
end

function love.system.getLanguage()
    if lv1lua.mode == "lpp-vita" then
        local fn = native(System, "getLanguage")
        if fn then return fn() end
    elseif lv1lua.mode == "OneLua" then
        local fn = native(os, "language")
        if fn then return fn() end
    end
    return "en"
end

function love.system.getUsername()
    if lv1lua.mode == "lpp-vita" then
        local fn = native(System, "getUsername")
        if fn then return fn() end
    elseif lv1lua.mode == "OneLua" then
        local fn = native(os, "nick")
        if fn then return fn() end
    end
    return ""
end

function love.system.getProcessorCount()
    return caps().cores or 1
end

-- ── Power ────────────────────────────────────────────────────────
-- Returns LOVE's (state, percent, seconds): "battery" / "charging" /
-- "charged" / "nobattery" / "unknown".
local function nativePower()
    if lv1lua.mode == "lpp-vita" then
        local pct = native(System, "getBatteryPercentage")
        if not pct then return nil end
        local life     = native(System, "getBatteryLife")
        local charging = native(System, "isBatteryCharging")
        -- lpp-vita reports remaining life in minutes; LOVE wants seconds.
        return pct(), life and life() * 60 or nil, charging and charging() or false
    end
    if lv1lua.mode == "OneLua" then
        -- OneLua's `os` module exposes no battery call we can rely on across
        -- its PSP and Vita builds, so it is probed rather than assumed.
        local pct = native(os, "battery")
        if not pct then return nil end
        local charging = native(os, "charging")
        return pct(), nil, charging and charging() or false
    end
    return nil
end

function love.system.getPowerInfo()
    if caps().battery == false then return "nobattery", nil, nil end

    local percent, seconds, charging = nativePower()
    if percent == nil then return "unknown", nil, nil end

    if charging then
        if percent >= 100 then return "charged", percent, seconds end
        return "charging", percent, seconds
    end
    return "battery", percent, seconds
end

-- ── Clipboard ────────────────────────────────────────────────────
-- No console here exposes a system clipboard, so it is process-local: a game
-- can still copy between its own fields, and the text is gone on exit.
lv1lua.clipboard = lv1lua.clipboard or ""

function love.system.setClipboardText(text)
    lv1lua.clipboard = tostring(text or "")
end

function love.system.getClipboardText()
    return lv1lua.clipboard
end

-- ── Hand-offs the SDKs do not offer ──────────────────────────────
-- LOVE returns whether the URL was handed to a browser. No SDK here has one,
-- so this is false rather than a silent no-op a game cannot detect.
function love.system.openURL(url)
    return false
end

-- The Vita and PSP have no rumble motor and no PS3 Lua player exposes one, so
-- this is a no-op; `love._backend.system.vibrate` records that.
function love.system.vibrate(seconds)
end

function love.system.hasBackgroundMusic()
    return false
end
