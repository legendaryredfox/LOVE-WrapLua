-- Key edge detection (#T4.4).
--
-- Console SDKs report "button is down"; LOVE games expect one keypressed per
-- press and one keyreleased per release. The shared tracker in core/input.lua
-- is tested directly, then each backend's updatecontrols is driven through its
-- native mock to prove it reports edges rather than per-frame state.

local T = dofile("tests/runner.lua")

local function fresh(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile("LOVE-WrapLua/core/loader.lua")
    lv1lua.load("LOVE-WrapLua/core/util.lua")
    lv1lua.load("LOVE-WrapLua/core/input.lua")
end

-- Records what the wrapper reports, in order.
local function recorder()
    local log = {}
    love.keypressed  = function(key, scancode, isrepeat)
        log[#log + 1] = { "pressed", key, scancode, isrepeat }
    end
    love.keyreleased = function(key, scancode)
        log[#log + 1] = { "released", key, scancode }
    end
    return log
end

local function countOf(log, kind, key)
    local n = 0
    for _, e in ipairs(log) do
        if e[1] == kind and (key == nil or e[2] == key) then n = n + 1 end
    end
    return n
end

-- ── the shared tracker ───────────────────────────────────────────
T.describe("core.input key tracker", function()
    T.it("a held button fires keypressed once, not once per frame", function()
        fresh("OneLua")
        local log = recorder()
        local keys = lv1lua.core.newKeyTracker()
        for _ = 1, 10 do keys:update({ a = true }, 0.016) end
        T.eq(countOf(log, "pressed", "a"), 1)
        T.eq(countOf(log, "released", "a"), 0)
    end)

    T.it("fires keyreleased once when the button goes up", function()
        fresh("OneLua")
        local log = recorder()
        local keys = lv1lua.core.newKeyTracker()
        keys:update({ a = true }, 0.016)
        for _ = 1, 5 do keys:update({ a = false }, 0.016) end
        T.eq(countOf(log, "released", "a"), 1)
    end)

    T.it("passes the key as scancode and isrepeat=false on a press", function()
        fresh("OneLua")
        local log = recorder()
        local keys = lv1lua.core.newKeyTracker()
        keys:update({ x = true }, 0.016)
        T.eq(log[1][2], "x")
        T.eq(log[1][3], "x")
        T.eq(log[1][4], false)
    end)

    T.it("a second press after a release fires again", function()
        fresh("OneLua")
        local log = recorder()
        local keys = lv1lua.core.newKeyTracker()
        keys:update({ a = true },  0.016)
        keys:update({ a = false }, 0.016)
        keys:update({ a = true },  0.016)
        T.eq(countOf(log, "pressed", "a"), 2)
        T.eq(countOf(log, "released", "a"), 1)
    end)

    T.it("tracks several buttons independently", function()
        fresh("OneLua")
        local log = recorder()
        local keys = lv1lua.core.newKeyTracker()
        keys:update({ a = true,  b = false }, 0.016)
        keys:update({ a = true,  b = true  }, 0.016)
        keys:update({ a = false, b = true  }, 0.016)
        T.eq(countOf(log, "pressed", "a"), 1)
        T.eq(countOf(log, "pressed", "b"), 1)
        T.eq(countOf(log, "released", "a"), 1)
        T.eq(countOf(log, "released", "b"), 0)
    end)

    T.it("releases a button the frame stops reporting entirely", function()
        fresh("OneLua")
        local log = recorder()
        local keys = lv1lua.core.newKeyTracker()
        keys:update({ a = true }, 0.016)
        keys:update({}, 0.016)  -- backend no longer mentions "a"
        T.eq(countOf(log, "released", "a"), 1)
    end)

    T.it("isDown reflects the tracked state", function()
        fresh("OneLua")
        recorder()
        local keys = lv1lua.core.newKeyTracker()
        keys:update({ a = true }, 0.016)
        T.ok(keys:isDown("a"))
        keys:update({ a = false }, 0.016)
        T.nok(keys:isDown("a"))
    end)
end)

-- ── key repeat ───────────────────────────────────────────────────
T.describe("core.input key repeat", function()
    T.it("is off by default, so holding never repeats", function()
        fresh("OneLua")
        local log = recorder()
        T.nok(love.keyboard.hasKeyRepeat())
        local keys = lv1lua.core.newKeyTracker()
        for _ = 1, 60 do keys:update({ a = true }, 0.1) end
        T.eq(countOf(log, "pressed", "a"), 1)
    end)

    T.it("repeats with isrepeat=true once enabled", function()
        fresh("OneLua")
        local log = recorder()
        love.keyboard.setKeyRepeat(true)
        local keys = lv1lua.core.newKeyTracker()
        -- 0.4s delay, then one every 0.05s: 1s of holding gives the initial
        -- press plus several repeats.
        for _ = 1, 100 do keys:update({ a = true }, 0.01 ) end
        T.ok(countOf(log, "pressed", "a") > 2, "should repeat while held")
        T.eq(log[1][4], false)   -- first event is the real press
        T.eq(log[2][4], true)    -- the rest are repeats
    end)

    T.it("waits out the delay before the first repeat", function()
        fresh("OneLua")
        local log = recorder()
        love.keyboard.setKeyRepeat(true)
        local keys = lv1lua.core.newKeyTracker()
        keys:update({ a = true }, 0.01)
        keys:update({ a = true }, 0.3)   -- 0.3s total, under the delay
        T.eq(countOf(log, "pressed", "a"), 1)
        keys:update({ a = true }, 0.2)   -- now past it
        T.eq(countOf(log, "pressed", "a"), 2)
    end)

    T.it("setKeyRepeat(false) stops further repeats", function()
        fresh("OneLua")
        local log = recorder()
        love.keyboard.setKeyRepeat(true)
        local keys = lv1lua.core.newKeyTracker()
        keys:update({ a = true }, 0.5)
        local afterFirst = countOf(log, "pressed", "a")
        love.keyboard.setKeyRepeat(false)
        for _ = 1, 20 do keys:update({ a = true }, 0.1) end
        T.eq(countOf(log, "pressed", "a"), afterFirst)
    end)
end)

-- ── per backend ──────────────────────────────────────────────────
T.describe("OneLua updatecontrols", function()
    local function load_onelua()
        fresh("OneLua")
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        lv1lua.load("LOVE-WrapLua/core/timestep.lua")
        lv1lua.timer = timer.new()
        lv1lua.load("LOVE-WrapLua/OneLua/graphics.lua")
        lv1lua.load("LOVE-WrapLua/OneLua/whileloop.lua")
        lv1lua.load("LOVE-WrapLua/OneLua/keyboard.lua")
        -- updatecontrols polls the Vita touchscreen through love.mouse.
        lv1lua.load("LOVE-WrapLua/OneLua/touch.lua")
        lv1lua.load("LOVE-WrapLua/OneLua/mouse.lua")
    end

    T.it("a held button fires keypressed once over many frames", function()
        load_onelua()
        local log = recorder()
        buttons.held = { up = true }
        for _ = 1, 10 do lv1lua.updatecontrols() end
        T.eq(countOf(log, "pressed", "up"), 1)
    end)

    T.it("fires keyreleased once when the button goes up", function()
        load_onelua()
        local log = recorder()
        buttons.held = { up = true }
        lv1lua.updatecontrols()
        buttons.held = {}
        for _ = 1, 5 do lv1lua.updatecontrols() end
        T.eq(countOf(log, "released", "up"), 1)
    end)

    T.it("maps the face buttons through lv1lua.keyset", function()
        load_onelua()
        local log = recorder()
        buttons.held = { circle = true }
        lv1lua.updatecontrols()
        T.eq(countOf(log, "pressed", lv1lua.keyset[1]), 1)
    end)

    T.it("does not leak dt as a global", function()
        load_onelua()
        dt = nil
        lv1lua.timer._elapsed = 20
        lv1lua.update()
        T.ok(dt == nil, "dt must not become a global")
        T.ok(lv1lua.dt and lv1lua.dt > 0, "lv1lua.dt should hold the frame time")
    end)
end)

T.describe("lpp-vita updatecontrols", function()
    local function load_lpp()
        fresh("lpp-vita")
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        lv1lua.load("LOVE-WrapLua/core/timestep.lua")
        lv1lua.load("LOVE-WrapLua/lpp-vita/graphics.lua")
        lv1lua.load("LOVE-WrapLua/lpp-vita/keyboard.lua")
        lv1lua.load("LOVE-WrapLua/lpp-vita/whileloop.lua")
        Controls._down = {}
    end

    T.it("a held button fires keypressed once over many frames", function()
        load_lpp()
        local log = recorder()
        Controls._down[lv1lua.keyenum[1]] = true  -- "up"
        for _ = 1, 10 do lv1lua.updatecontrols() end
        T.eq(countOf(log, "pressed", "up"), 1)
    end)

    T.it("fires keyreleased once and clears isDown", function()
        load_lpp()
        local log = recorder()
        Controls._down[lv1lua.keyenum[1]] = true
        lv1lua.updatecontrols()
        T.ok(love.keyboard.isDown("up"), "isDown should follow the pad")
        Controls._down[lv1lua.keyenum[1]] = nil
        for _ = 1, 5 do lv1lua.updatecontrols() end
        T.eq(countOf(log, "released", "up"), 1)
        T.nok(love.keyboard.isDown("up"))
    end)

    T.it("does not leak dt as a global", function()
        load_lpp()
        dt = nil
        Timer._elapsed = 20
        lv1lua.update()
        T.ok(dt == nil, "dt must not become a global")
    end)
end)

T.describe("PS3 updatecontrols", function()
    local function load_ps3()
        fresh("PS3")
        lv1lua.load("LOVE-WrapLua/core/config.lua")
        lv1lua.load("LOVE-WrapLua/core/timestep.lua")
        lv1lua.load("LOVE-WrapLua/PS3/graphics.lua")
        lv1lua.load("LOVE-WrapLua/PS3/keyboard.lua")
        lv1lua.load("LOVE-WrapLua/PS3/whileloop.lua")
        pad._down = {}
    end

    T.it("a held button fires keypressed once over many frames", function()
        load_ps3()
        local log = recorder()
        pad._down.up = true
        for _ = 1, 10 do lv1lua.updatecontrols() end
        T.eq(countOf(log, "pressed", "up"), 1)
    end)

    T.it("fires keyreleased once and clears isDown", function()
        load_ps3()
        local log = recorder()
        pad._down.up = true
        lv1lua.updatecontrols()
        T.ok(love.keyboard.isDown("up"), "isDown should follow the pad")
        pad._down.up = nil
        for _ = 1, 5 do lv1lua.updatecontrols() end
        T.eq(countOf(log, "released", "up"), 1)
        T.nok(love.keyboard.isDown("up"))
    end)

    T.it("uses a fixed frame time on lv1lua, not a global dt", function()
        load_ps3()
        dt = nil
        T.ok(dt == nil, "dt must not become a global")
        T.near(lv1lua.dt, 1 / 60, 1e-9)
    end)
end)

io.write("\n=== input edges (core + all backends) ===\n")
return T.summary()
