-- Boot-level modules: config, require, callbacks, touch/mouse and the frame
-- loop's input handling (CODE_REVIEW R1, R2, R4, R5, R6, R7, R21).
--
-- These were the only modules with no coverage at all, which is exactly why a
-- Vita build could crash on its first frame with the default configuration and
-- the suite stayed green.

local T = dofile("tests/runner.lua")

local function fresh(mode, keyconf)
    __MODE = mode or "OneLua"
    dofile("tests/setup.lua")
    lv1luaconf = { keyconf = keyconf or "XB", imgscale = false, resscale = false }
    lv1lua.core = lv1lua.core or {}
    dofile("LOVE-WrapLua/core/util.lua")
    dofile("LOVE-WrapLua/core/input.lua")
    dofile("LOVE-WrapLua/core/config.lua")
end

-- ── Vita input modules are not tied to the button layout (R1) ────
T.describe("core/config loads the Vita input modules", function()
    T.it("touch and mouse exist with the default XB layout", function()
        fresh("OneLua", "XB")
        T.istype(love.touch.getTouches, "function")
        T.istype(love.mouse.getPosition, "function")
    end)

    T.it("they also exist with the PS layout", function()
        fresh("OneLua", "PS")
        T.istype(love.touch.getTouches, "function")
        T.istype(love.mouse.isDown, "function")
    end)

    T.it("PSP gets no touchscreen modules", function()
        __MODE = "PSP"
        dofile("tests/setup.lua")
        lv1luaconf = { keyconf = "XB" }
        dofile("LOVE-WrapLua/core/util.lua")
        dofile("LOVE-WrapLua/core/input.lua")
        dofile("LOVE-WrapLua/core/config.lua")
        T.eq(love.touch.getTouches, nil)
    end)

    T.it("the button layout still follows keyconf", function()
        fresh("OneLua", "PS")
        T.eq(lv1lua.keyset[1], "circle")
        fresh("OneLua", "XB")
        T.eq(lv1lua.keyset[1], "b")
    end)
end)

-- ── touch positions (R4) ─────────────────────────────────────────
T.describe("love.touch", function()
    T.it("reports the position of the first touch", function()
        fresh("OneLua", "XB")
        touch.front = { count = 1, [1] = { x = 120, y = 240, pressed = true } }
        love.touch.__getFrontTouches(touch)
        local x, y = love.touch.getPosition(1)
        T.eq(x, 120)
        T.eq(y, 240)
    end)

    T.it("an id beyond the touch count is 0, 0", function()
        fresh("OneLua", "XB")
        touch.front = { count = 1, [1] = { x = 5, y = 6, pressed = true } }
        love.touch.__getFrontTouches(touch)
        local x, y = love.touch.getPosition(2)
        T.eq(x, 0)
        T.eq(y, 0)
    end)

    T.it("the mouse follows the touch instead of sitting at the origin", function()
        fresh("OneLua", "XB")
        touch.front = { count = 1, [1] = { x = 300, y = 150, pressed = true } }
        love.touch.__getFrontTouches(touch)
        love.mouse.__updateMouse()
        T.eq(love.mouse.getX(), 300)
        T.eq(love.mouse.getY(), 150)
        T.ok(love.mouse.isDown(), "a pressed touch is a held mouse button")
    end)

    T.it("no touch means no mouse button down", function()
        fresh("OneLua", "XB")
        touch.front = { count = 0 }
        love.touch.__getFrontTouches(touch)
        T.nok(love.mouse.isDown())
    end)
end)

-- ── require shim (R7) ────────────────────────────────────────────
-- The shim replaces the global `require`, so the interpreter's own is put back
-- once these cases are done: later suites (and the vendored libraries they
-- load) still need it.
local systemRequire = require

local function loadRequire(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    lv1lua.mode    = mode
    lv1lua.dataloc = "tests/fixtures/requireroot/"
    __requireModLoads = 0
    dofile("LOVE-WrapLua/core/require.lua")
end

T.describe("core/require", function()
    T.it("resolves a dotted module name", function()
        loadRequire("lpp-vita")
        local mod = require("libraries.mod")
        T.istype(mod, "table")
        T.eq(mod.name, "mod")
    end)

    T.it("resolves a slashed module name", function()
        loadRequire("lpp-vita")
        T.eq(require("libraries/mod").name, "mod")
    end)

    T.it("resolves a name that already ends in .lua", function()
        loadRequire("lpp-vita")
        T.eq(require("plain.lua").name, "plain")
    end)

    T.it("runs a module once and caches it, as require does", function()
        loadRequire("lpp-vita")
        local a = require("libraries.mod")
        local b = require("libraries.mod")
        T.eq(__requireModLoads, 1)
        T.ok(a == b, "the same table must come back")
    end)

    T.it("dotted and slashed spellings share one cached module", function()
        loadRequire("lpp-vita")
        local a = require("libraries.mod")
        local b = require("libraries/mod")
        T.eq(__requireModLoads, 1)
        T.ok(a == b)
    end)

    T.it("a module that is not in game/ falls back to the interpreter", function()
        loadRequire("lpp-vita")
        -- The vendored crypto asks LuaJIT for "bit" this way; on plain Lua the
        -- fallback is expected to fail, but it must be the interpreter failing,
        -- not the shim claiming the file is missing from game/.
        local ok, err = pcall(require, "string")
        T.ok(ok, "a standard module must resolve: " .. tostring(err))
    end)
end)

require = systemRequire

-- ── gamepad bridging (R21 coverage) ──────────────────────────────
T.describe("core/callbacks", function()
    local function wire(setup)
        __MODE = "OneLua"
        dofile("tests/setup.lua")
        dofile("LOVE-WrapLua/joystick.lua")
        setup()
        dofile("LOVE-WrapLua/core/callbacks.lua")
    end

    T.it("a game with only gamepadpressed still receives key presses", function()
        local got
        wire(function()
            love.gamepadpressed = function(js, button) got = button end
        end)
        love.keypressed("a")
        T.eq(got, "a")
    end)

    T.it("a game's own keypressed is left alone", function()
        local seen
        wire(function()
            love.keypressed = function(key) seen = key end
            love.gamepadpressed = function() seen = "bridged" end
        end)
        love.keypressed("x")
        T.eq(seen, "x")
    end)

    T.it("every optional callback becomes a no-op instead of a nil", function()
        wire(function() end)
        for _, name in ipairs({"keypressed","keyreleased","mousepressed","mousereleased",
                               "mousemoved","wheelmoved","touchpressed","touchreleased",
                               "touchmoved","focus","visible","resize","lowmemory",
                               "textinput","threaderror"}) do
            T.istype(love[name], "function")
        end
    end)
end)

-- ── the frame loop's pad handling (R5, R6) ───────────────────────
local function loadLoop()
    fresh("OneLua", "XB")
    dofile("LOVE-WrapLua/joystick.lua")
    dofile("LOVE-WrapLua/OneLua/timer.lua")
    dofile("LOVE-WrapLua/core/callbacks.lua")
    dofile("LOVE-WrapLua/OneLua/whileloop.lua")
    buttons.held = {}
    touch.front  = { count = 0 }
end

T.describe("OneLua frame loop", function()
    T.it("L+R+Down alone does not restart the app", function()
        loadLoop()
        local restarts = 0
        os.restart = function() restarts = restarts + 1 end
        buttons.held = { l = true, r = true, down = true }
        lv1lua.updatecontrols()
        T.eq(restarts, 0)
    end)

    T.it("the full combo with start does restart", function()
        loadLoop()
        local restarts = 0
        os.restart = function() restarts = restarts + 1 end
        buttons.held = { l = true, r = true, down = true, start = true }
        lv1lua.updatecontrols()
        T.eq(restarts, 1)
    end)

    T.it("the joystick sees the buttons the pad reports", function()
        loadLoop()
        buttons.held = { cross = true }
        lv1lua.updatecontrols()
        local js = love.joystick.getJoysticks()[1]
        -- keyset[2] ("a" in the XB layout) is the cross button.
        T.ok(js:isGamepadDown("a"), "cross should read as the gamepad's a")
        T.nok(js:isGamepadDown("b"), "circle is not held")
    end)

    T.it("the d-pad drives the hat", function()
        loadLoop()
        buttons.held = { up = true }
        lv1lua.updatecontrols()
        T.eq(love.joystick.getJoysticks()[1]:getHat(1), "u")

        buttons.held = { up = true, left = true }
        lv1lua.updatecontrols()
        T.eq(love.joystick.getJoysticks()[1]:getHat(1), "lu")

        buttons.held = {}
        lv1lua.updatecontrols()
        T.eq(love.joystick.getJoysticks()[1]:getHat(1), "c")
    end)

    T.it("a frame with a touch does not error", function()
        loadLoop()
        touch.front = { count = 1, [1] = { x = 10, y = 20, pressed = true } }
        lv1lua.updatecontrols()
        T.eq(love.mouse.getX(), 10)
    end)
end)

io.write("\n=== boot modules (config, require, callbacks, touch, loop) ===\n")
return T.summary()
