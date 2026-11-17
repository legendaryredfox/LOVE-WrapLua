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

T.describe("Vita front touch", function()
    local function vitaLoop()
        loop_for("OneLua", "LOVE-WrapLua/OneLua/whileloop.lua", function()
            lv1lua.load("LOVE-WrapLua/OneLua/graphics.lua")
            lv1lua.load("LOVE-WrapLua/OneLua/touch.lua")
            lv1lua.load("LOVE-WrapLua/OneLua/mouse.lua")
        end)
        buttons.held = {}
    end

    T.it("emits press, move and release edges per finger", function()
        vitaLoop()
        local log = {}
        for _, n in ipairs({ "touchpressed", "touchmoved", "touchreleased", "mousepressed", "mousemoved", "mousereleased" }) do
            love[n] = function(...) log[#log + 1] = { n, ... } end
        end
        touch.front = { count = 1, { x = 10, y = 20 } }
        lv1lua.updatecontrols()
        T.eq(log[1][1], "touchpressed"); T.eq(log[1][2], 1); T.eq(log[1][3], 10); T.eq(log[1][4], 20)
        T.eq(log[2][1], "mousepressed")
        log = {}
        lv1lua.updatecontrols()
        T.eq(#log, 0, "a finger that did not move is silent")
        touch.front = { count = 1, { x = 13, y = 24 } }
        lv1lua.updatecontrols()
        T.eq(log[1][1], "touchmoved"); T.eq(log[1][5], 3); T.eq(log[1][6], 4)
        log = {}
        touch.front = { count = 0 }
        lv1lua.updatecontrols()
        T.eq(log[1][1], "touchreleased"); T.eq(log[1][3], 13); T.eq(log[1][4], 24)
        T.eq(log[2][1], "mousereleased")
    end)

    T.it("a held finger costs no allocation per frame", function()
        if jit then return end
        vitaLoop()
        touch.front = { count = 2, { x = 10, y = 20 }, { x = 30, y = 40 } }
        for _ = 1, 50 do lv1lua.updatecontrols() end
        collectgarbage(); collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 50 do lv1lua.updatecontrols() end
        local grew = (collectgarbage("count") - before) * 1024
        collectgarbage("restart")
        T.ok(grew < 50 * 100, "allocated " .. grew .. " bytes in 50 frames")
    end)
end)

io.write("\n=== main loop ===\n")
return T.summary()
