-- Main loop: the per-frame input tables are reused, and lv1luaconf.frameskip lets the loop skip love.draw
-- while love.update is behind.

local T = dofile("tests/runner.lua")

local function fresh(mode, conf)
    __MODE = mode
    dofile("tests/setup.lua")
    if conf then for k, v in pairs(conf) do lv1luaconf[k] = v end end
    dofile("LOVE-WrapLua/core/loader.lua")
    lv1lua.load("LOVE-WrapLua/core/util.lua")
    lv1lua.load("LOVE-WrapLua/core/input.lua")
    lv1lua.load("LOVE-WrapLua/core/config.lua")
    lv1lua.load("LOVE-WrapLua/core/timestep.lua")
end

local STEP = 1 / 60

T.describe("frameskip", function()
    T.it("is off by default: every frame draws, however far behind", function()
        fresh("OneLua")
        for _ = 1, 10 do
            lv1lua.core.step(STEP * 4)
            T.ok(lv1lua.core.shouldDraw())
        end
    end)

    T.it("skips the draw after a frame that ran two or more slices, up to the limit", function()
        fresh("OneLua", { frameskip = 2 })
        T.ok(lv1lua.core.shouldDraw(), "the first frame always draws")
        lv1lua.core.step(STEP * 3)
        T.nok(lv1lua.core.shouldDraw())
        lv1lua.core.step(STEP * 3)
        T.nok(lv1lua.core.shouldDraw())
        lv1lua.core.step(STEP * 3)
        T.ok(lv1lua.core.shouldDraw(), "a third skip in a row is refused")
        lv1lua.core.step(STEP * 3)
        T.nok(lv1lua.core.shouldDraw(), "the count starts again after a draw")
    end)

    T.it("draws when the last frame ran at most one slice", function()
        fresh("OneLua", { frameskip = 3 })
        lv1lua.core.step(STEP)
        T.ok(lv1lua.core.shouldDraw())
        lv1lua.core.step(0.001)
        T.ok(lv1lua.core.shouldDraw())
    end)

    T.it("never skips with the variable timestep", function()
        fresh("OneLua", { frameskip = 3, updaterate = "variable" })
        lv1lua.core.step(0.2)
        T.ok(lv1lua.core.shouldDraw())
    end)
end)

local function loop_for(mode, file, extra)
    fresh(mode)
    lv1lua.timer = timer and timer.new and timer.new() or lv1lua.timer
    if extra then extra() end
    lv1lua.load(file)
end

T.describe("updatecontrols reuses its tables", function()
    T.it("OneLua samples the buttons without allocating", function()
        if jit then return end
        loop_for("OneLua", "LOVE-WrapLua/OneLua/whileloop.lua", function()
            lv1lua.load("LOVE-WrapLua/OneLua/graphics.lua")
            lv1lua.load("LOVE-WrapLua/OneLua/touch.lua")
            lv1lua.load("LOVE-WrapLua/OneLua/mouse.lua")
        end)
        buttons.held = { up = true }
        for _ = 1, 50 do lv1lua.updatecontrols() end
        collectgarbage(); collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 50 do lv1lua.updatecontrols() end
        local grew = (collectgarbage("count") - before) * 1024
        collectgarbage("restart")
        T.ok(grew < 50 * 100, "allocated " .. grew .. " bytes in 50 frames")
    end)

    T.it("a button that was held and let go is released, not remembered from an earlier frame", function()
        loop_for("OneLua", "LOVE-WrapLua/OneLua/whileloop.lua", function()
            lv1lua.load("LOVE-WrapLua/OneLua/graphics.lua")
            lv1lua.load("LOVE-WrapLua/OneLua/touch.lua")
            lv1lua.load("LOVE-WrapLua/OneLua/mouse.lua")
        end)
        local released = 0
        love.keyreleased = function() released = released + 1 end
        buttons.held = { up = true, circle = true }
        lv1lua.updatecontrols()
        buttons.held = { up = true }
        lv1lua.updatecontrols()
        T.eq(released, 1)
        T.eq(lv1lua.joystickState.buttons[2], false)
        T.eq(lv1lua.joystickState.hats[1], "u")
    end)
end)

io.write("\n=== main loop ===\n")
return T.summary()
