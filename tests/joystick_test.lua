local T = dofile("tests/runner.lua")
dofile("tests/mock_platform.lua")
dofile("LOVE-WrapLua/joystick.lua")

-- ── Module-level accessors ───────────────────────────────────────
T.describe("love.joystick top-level", function()
    T.it("getJoysticks returns a table with exactly one entry", function()
        local js = love.joystick.getJoysticks()
        T.istype(js, "table")
        T.eq(#js, 1)
    end)

    T.it("getJoystickCount returns 1", function()
        T.eq(love.joystick.getJoystickCount(), 1)
    end)
end)

-- ── Joystick object ──────────────────────────────────────────────
local joystick = love.joystick.getJoysticks()[1]

T.describe("Joystick:isConnected / isGamepad", function()
    T.it("isConnected returns true", function()   T.ok(joystick:isConnected())  end)
    T.it("isGamepad returns true",   function()   T.ok(joystick:isGamepad())    end)
end)

T.describe("Joystick:getName / getID", function()
    T.it("getName returns a string containing 'Controller'", function()
        local name = joystick:getName()
        T.istype(name, "string")
        T.ok(name:find("Controller"), "name should contain 'Controller'")
    end)

    T.it("getID returns two values (integer and string)", function()
        local id, guid = joystick:getID()
        T.istype(id,   "number")
        T.istype(guid, "string")
    end)
end)

T.describe("Joystick:getAxisCount / getButtonCount / getHatCount", function()
    T.it("getAxisCount returns 6", function()
        T.eq(joystick:getAxisCount(), 6)
    end)
    T.it("getButtonCount returns 15", function()
        T.eq(joystick:getButtonCount(), 15)
    end)
    T.it("getHatCount returns 1", function()
        T.eq(joystick:getHatCount(), 1)
    end)
end)

T.describe("Joystick:getAxis", function()
    T.it("all axes default to 0", function()
        lv1lua.joystickState.axes = {0,0,0,0,0,0}
        for i = 1, 6 do
            T.eq(joystick:getAxis(i), 0)
        end
    end)

    T.it("reflects updated axis state", function()
        lv1lua.joystickState.axes[1] = 0.75
        T.eq(joystick:getAxis(1), 0.75)
        lv1lua.joystickState.axes[1] = 0  -- restore
    end)

    T.it("getAxes returns all six values", function()
        lv1lua.joystickState.axes = {0.1, 0.2, 0.3, 0.4, 0.5, 0.6}
        local a, b, c, d, e, f = joystick:getAxes()
        T.near(a, 0.1); T.near(b, 0.2); T.near(c, 0.3)
        T.near(d, 0.4); T.near(e, 0.5); T.near(f, 0.6)
        lv1lua.joystickState.axes = {0,0,0,0,0,0}
    end)
end)

T.describe("Joystick:isDown", function()
    T.it("returns false when no buttons pressed", function()
        lv1lua.joystickState.buttons = {}
        T.nok(joystick:isDown(1))
    end)

    T.it("returns true when button is marked pressed", function()
        lv1lua.joystickState.buttons[3] = true
        T.ok(joystick:isDown(3))
        lv1lua.joystickState.buttons[3] = nil
    end)

    T.it("accepts multiple button indices (any-pressed)", function()
        lv1lua.joystickState.buttons[5] = true
        T.ok(joystick:isDown(1, 2, 5))
        lv1lua.joystickState.buttons[5] = nil
    end)
end)

T.describe("Joystick:isGamepadDown", function()
    T.it("'a' maps to button index 1", function()
        lv1lua.joystickState.buttons[1] = true
        T.ok(joystick:isGamepadDown("a"))
        lv1lua.joystickState.buttons[1] = nil
    end)

    T.it("unknown gamepad name returns false", function()
        T.nok(joystick:isGamepadDown("unknown_button"))
    end)
end)

T.describe("Joystick:getGamepadAxis", function()
    T.it("leftx maps to axis 1", function()
        lv1lua.joystickState.axes[1] = -0.5
        T.near(joystick:getGamepadAxis("leftx"), -0.5)
        lv1lua.joystickState.axes[1] = 0
    end)

    T.it("righty maps to axis 4", function()
        lv1lua.joystickState.axes[4] = 1.0
        T.near(joystick:getGamepadAxis("righty"), 1.0)
        lv1lua.joystickState.axes[4] = 0
    end)
end)

T.describe("Joystick:getHat", function()
    T.it("hat 1 defaults to 'c' (centered)", function()
        lv1lua.joystickState.hats = { "c" }
        T.eq(joystick:getHat(1), "c")
    end)
end)

T.describe("Joystick:isVibrationSupported", function()
    T.it("returns false", function()
        T.nok(joystick:isVibrationSupported())
    end)
end)

io.write("\n=== love.joystick ===\n")
return T.summary()
