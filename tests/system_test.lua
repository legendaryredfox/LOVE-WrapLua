-- love.system across the backends (FIX_PLAN T6.1).
--
-- Every call has to answer something sane on a console: either the native value
-- or the documented fallback. Nothing here may error, because a game that asks
-- for battery level on a PSP must keep running.

local T = dofile("tests/runner.lua")

local function load_backend(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile("LOVE-WrapLua/core/capabilities.lua")
    lv1lua.core.installCapabilities(mode)
    dofile("LOVE-WrapLua/system.lua")
end

local POWER_STATES = { battery = true, charging = true, charged = true,
                       nobattery = true, unknown = true }

local function shared_suite(mode)
    T.describe("love.system [" .. mode .. "]", function()
        T.it("getOS answers", function()
            T.istype(love.system.getOS(), "string")
        end)

        T.it("getProcessorCount is a positive integer", function()
            local n = love.system.getProcessorCount()
            T.istype(n, "number")
            T.ok(n >= 1, "at least one core")
            T.eq(n, math.floor(n))
        end)

        T.it("getPowerInfo returns a LOVE power state", function()
            local state, percent, seconds = love.system.getPowerInfo()
            T.ok(POWER_STATES[state], "unknown power state: " .. tostring(state))
            if percent ~= nil then T.inrange(percent, 0, 100) end
            if seconds ~= nil then T.ok(seconds >= 0, "seconds cannot be negative") end
        end)

        T.it("clipboard round-trips", function()
            T.eq(love.system.getClipboardText(), "")
            love.system.setClipboardText("hello")
            T.eq(love.system.getClipboardText(), "hello")
            love.system.setClipboardText("")
        end)

        T.it("openURL reports whether it worked", function()
            T.istype(love.system.openURL("https://love2d.org"), "boolean")
        end)

        T.it("vibrate never errors", function()
            love.system.vibrate()
            love.system.vibrate(0.5)
        end)

        T.it("getLanguage / getUsername answer a string", function()
            T.istype(love.system.getLanguage(), "string")
            T.istype(love.system.getUsername(), "string")
        end)
    end)
end

for _, mode in ipairs({"OneLua", "PSP", "lpp-vita", "PS3"}) do
    load_backend(mode)
    shared_suite(mode)
end

-- ── Native power where the SDK exposes it ────────────────────────
load_backend("lpp-vita")
T.describe("love.system power [lpp-vita]", function()
    T.it("reports the native battery percentage and converts minutes to seconds", function()
        __battery = { percent = 55, minutes = 90, charging = false }
        local state, percent, seconds = love.system.getPowerInfo()
        T.eq(state, "battery")
        T.eq(percent, 55)
        T.eq(seconds, 90 * 60)
    end)

    T.it("charging is reported as charging", function()
        __battery = { percent = 40, minutes = 0, charging = true }
        T.eq(love.system.getPowerInfo(), "charging")
    end)

    T.it("a full battery on the charger is charged", function()
        __battery = { percent = 100, minutes = 0, charging = true }
        T.eq(love.system.getPowerInfo(), "charged")
        __battery = { percent = 55, minutes = 90, charging = false }
    end)

    T.it("native language and username are used", function()
        T.eq(love.system.getLanguage(), "en")
        T.eq(love.system.getUsername(), "VitaPlayer")
    end)
end)

-- ── PS3 has no battery ───────────────────────────────────────────
load_backend("PS3")
T.describe("love.system power [PS3]", function()
    T.it("a home console reports nobattery", function()
        T.eq(love.system.getPowerInfo(), "nobattery")
    end)
end)

-- ── OneLua falls back where the SDK has no call ──────────────────
load_backend("OneLua")
T.describe("love.system fallbacks [OneLua]", function()
    T.it("no native battery call means unknown, not a crash", function()
        local state, percent = love.system.getPowerInfo()
        T.ok(state == "unknown" or state == "battery")
        if state == "unknown" then T.eq(percent, nil) end
    end)

    T.it("native language and username come from os.*", function()
        T.eq(love.system.getLanguage(), "en")
        T.eq(love.system.getUsername(), "Player")
    end)
end)

io.write("\n=== love.system (multi-backend) ===\n")
return T.summary()
