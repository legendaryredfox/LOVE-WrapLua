-- Joystick:setVibration. lpp-vita is the one backend whose player exposes a rumble call
-- (Controls.rumble); the others answer "not supported" and ignore the call.

local T = dofile("tests/runner.lua")

local function boot(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile("LOVE-WrapLua/core/loader.lua")
    lv1lua.load("LOVE-WrapLua/core/util.lua")
    lv1lua.load("LOVE-WrapLua/core/input.lua")
    lv1lua.load("LOVE-WrapLua/core/config.lua")
    lv1lua.load("LOVE-WrapLua/core/timestep.lua")
    if mode == "lpp-vita" then lv1lua.load("LOVE-WrapLua/lpp-vita/whileloop.lua") end
    lv1lua.load("LOVE-WrapLua/joystick.lua")
    love.update = love.update or function() end
    return love.joystick.getJoysticks()[1]
end

T.describe("vibration [lpp-vita]", function()
    T.it("is supported", function()
        local js = boot("lpp-vita")
        T.ok(js:isVibrationSupported())
    end)

    T.it("setVibration drives both motors with the larger intensity, scaled to 0..255", function()
        local js = boot("lpp-vita")
        __rec.reset()
        T.ok(js:setVibration(0.5, 1))
        local c = __rec.last("Controls.rumble")
        T.eq(c.args[1], 1)
        T.eq(c.args[2], 255)
        T.eq(c.args[3], 255)
    end)

    T.it("getVibration reads back what was set", function()
        local js = boot("lpp-vita")
        js:setVibration(0.25, 0.75)
        local l, r = js:getVibration()
        T.near(l, 0.25, 1e-9)
        T.near(r, 0.75, 1e-9)
    end)

    T.it("a duration stops the motors once that much update time has passed", function()
        local js = boot("lpp-vita")
        __rec.reset()
        js:setVibration(1, 1, 0.5)
        lv1lua.core.step(0.3)
        T.eq(__rec.count("Controls.rumble"), 1)
        lv1lua.core.step(0.3)
        T.eq(__rec.count("Controls.rumble"), 2)
        T.eq(__rec.last("Controls.rumble").args[3], 0)
        local l, r = js:getVibration()
        T.eq(l, 0); T.eq(r, 0)
    end)

    T.it("setVibration() with no arguments stops it", function()
        local js = boot("lpp-vita")
        js:setVibration(1, 1)
        __rec.reset()
        js:setVibration()
        T.eq(__rec.last("Controls.rumble").args[3], 0)
    end)

    T.it("intensities are clamped to 0..1", function()
        local js = boot("lpp-vita")
        __rec.reset()
        js:setVibration(3, -1)
        T.eq(__rec.last("Controls.rumble").args[3], 255)
        local l, r = js:getVibration()
        T.eq(l, 1); T.eq(r, 0)
    end)

    T.it("a repeated identical setting is not sent twice", function()
        local js = boot("lpp-vita")
        js:setVibration(0, 0)
        __rec.reset()
        js:setVibration(0.5, 0.5)
        js:setVibration(0.5, 0.5)
        T.eq(__rec.count("Controls.rumble"), 1)
    end)
end)

for _, mode in ipairs({ "OneLua", "PSP", "PS3", "3DS" }) do
    T.describe("vibration [" .. mode .. "]", function()
        T.it("is not supported and setVibration is harmless", function()
            local js = boot(mode)
            T.nok(js:isVibrationSupported())
            T.nok(js:setVibration(1, 1, 1))
            local l, r = js:getVibration()
            T.eq(l, 0); T.eq(r, 0)
            lv1lua.core.step(2)
        end)
    end)
end

io.write("\n=== vibration ===\n")
return T.summary()
