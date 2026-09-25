-- Global namespace boundary (FIX_PLAN T7.3).
--
-- The wrapper shares one _G with the game it runs, so anything it leaves in
-- there is a name the game cannot use. The boot sequence and one full frame
-- are run under a watcher on _G, and every new name has to be one the wrapper
-- deliberately owns.

local T = dofile("tests/runner.lua")

-- What the wrapper is allowed to define, and why.
local ALLOWED = {
    love        = "the LOVE API itself",
    lv1lua      = "wrapper runtime state",
    lv1luaconf  = "wrapper config, a game may set it first",
    require     = "redirected into game/ (core/require.lua)",
    __mathRound = "legacy alias kept for games written against the old wrapper",
    loadstring  = "PS3 runs Lua 5.2+, where loadstring was removed",
}

-- Native SDK names a backend guards with `x = x or {}`: on device the SDK
-- defines them, so creating them is only a fallback, never a new namespace.
local SDK_FALLBACK = { buttons = true }

local function watch()
    local seen = {}
    setmetatable(_G, {
        __newindex = function(t, k, v)
            seen[#seen + 1] = k
            rawset(t, k, v)
        end,
    })
    return seen
end

local function unwatch()
    setmetatable(_G, nil)
end

local function unexpected(seen)
    local bad = {}
    for _, name in ipairs(seen) do
        if not ALLOWED[name] and not SDK_FALLBACK[name] then
            bad[#bad + 1] = name
        end
    end
    return bad
end

local function list(names)
    return table.concat(names, ", ")
end

-- The boot sequence of script.lua, without the game itself.
local function boot(mode)
    __MODE = mode
    dofile("tests/setup.lua")
    dofile("LOVE-WrapLua/core/loader.lua")

    local seen = watch()
    local ok, err = pcall(function()
        lv1lua.loadOnce("LOVE-WrapLua/core/util.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/transform.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/textwrap.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/runtime.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/input.lua")
        lv1lua.load("LOVE-WrapLua/love-functions/thread.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/config.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/timestep.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/modules.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/require.lua")
        lv1lua.loadOnce("LOVE-WrapLua/core/callbacks.lua")
    end)
    unwatch()
    if not ok then error(err, 0) end
    return seen
end

local MODES = { "OneLua", "PSP", "lpp-vita", "PS3" }

for _, mode in ipairs(MODES) do
    T.describe("global boundary [" .. mode .. "]", function()
        T.it("boot defines only the names the wrapper owns", function()
            local bad = unexpected(boot(mode))
            T.ok(#bad == 0, "leaked globals: " .. list(bad))
        end)

        T.it("a frame defines no globals at all", function()
            boot(mode)
            local seen = watch()
            local ok, err = pcall(function()
                lv1lua.draw()
                lv1lua.update()
                lv1lua.updatecontrols()
            end)
            unwatch()
            if not ok then error(err, 0) end
            T.ok(#seen == 0, "a frame leaked: " .. list(seen))
        end)

        T.it("running the game's callbacks defines no globals", function()
            boot(mode)
            love.update = function() end
            love.draw   = function() end
            local seen = watch()
            local ok, err = pcall(function()
                for _ = 1, 3 do
                    lv1lua.draw()
                    lv1lua.update()
                    lv1lua.updatecontrols()
                end
            end)
            unwatch()
            love.update, love.draw = nil, nil
            if not ok then error(err, 0) end
            T.ok(#seen == 0, "the callback path leaked: " .. list(seen))
        end)
    end)
end

-- A frame only reaches the loop itself. Most of the wrapper is the API the
-- game calls, so the public surface is swept too: a missing `local` inside any
-- of these shows up as a new name in _G.
local function sweep()
    local img  = love.graphics.newImage("fixtures/test.png")
    local font = love.graphics.newFont(12)
    local quad = love.graphics.newQuad(0, 0, 8, 8, img)

    love.graphics.setColor(1, 0.5, 0, 1)
    love.graphics.getColor()
    love.graphics.setBackgroundColor(0, 0, 0)
    love.graphics.clear()
    love.graphics.push()
    love.graphics.translate(5, 5)
    love.graphics.scale(2, 2)
    love.graphics.rotate(0.5)
    love.graphics.origin()
    love.graphics.pop()
    love.graphics.draw(img, 1, 2)
    love.graphics.draw(img, quad, 1, 2, 0, 2, 2)
    love.graphics.rectangle("fill", 0, 0, 10, 10)
    love.graphics.rectangle("line", 0, 0, 10, 10)
    love.graphics.circle("fill", 5, 5, 4)
    love.graphics.circle("line", 5, 5, 4)
    love.graphics.ellipse("line", 5, 5, 4, 2)
    love.graphics.arc("line", 5, 5, 4, 0, 1)
    love.graphics.polygon("fill", 0, 0, 10, 0, 10, 10)
    love.graphics.line(0, 0, 10, 10)
    love.graphics.points(1, 1, 2, 2)
    love.graphics.setFont(font)
    love.graphics.print("hello", 1, 1)
    love.graphics.printf("a longer line of text", 0, 0, 40, "center")
    love.graphics.setLineWidth(2)
    love.graphics.setBlendMode("add")
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.getDimensions()
    love.graphics.getSupported()
    love.graphics.getSystemLimits()
    love.graphics.newCanvas(16, 16)
    love.graphics.newSpriteBatch(img, 4)
    love.graphics.newText(font, "batched")

    font:getWidth("hello")
    font:getHeight()
    font:getWrap("a longer line of text", 40)

    love.timer.getTime()
    love.timer.getDelta()
    love.timer.getFPS()
    love.timer.getAverageDelta()
    love.timer.step()

    love.math.random()
    love.math.newRandomGenerator(1, 2):random(1, 10)
    love.math.noise(0.5, 0.5)
    love.math.newTransform()

    love.data.encode("string", "base64", "payload")
    love.data.hash("md5", "payload")

    love.filesystem.getInfo("game/main.lua")
    love.filesystem.getIdentity()
    love.filesystem.getDirectoryItems("")
    love.filesystem.write("globals_probe.txt", "x")
    love.filesystem.read("globals_probe.txt")
    love.filesystem.remove("globals_probe.txt")

    love.keyboard.isDown("a")
    love.keyboard.setKeyRepeat(true)
    love.keyboard.setKeyRepeat(false)

    love.joystick.getJoysticks()
    love.system.getOS()
    love.system.getPowerInfo()
    love.window.getMode()

    local src = love.audio.newSource("fixtures/test.wav", "static")
    if src then
        src:play(); src:setVolume(0.5); src:isPlaying(); src:stop()
    end
    love.audio.setVolume(0.5)
end

for _, mode in ipairs(MODES) do
    T.describe("global boundary [" .. mode .. "]", function()
        T.it("the public love.* surface defines no globals", function()
            boot(mode)
            local seen = watch()
            local ok, err = pcall(sweep)
            unwatch()
            -- The sweep has to reach the end: a call erroring halfway would
            -- quietly shrink what this test covers.
            if not ok then error(err, 0) end
            T.ok(#seen == 0, "the API surface leaked: " .. list(seen))
        end)
    end)
end

-- The wrapper's own state has to stay reachable from the one entry table.
T.describe("lv1lua entry table", function()
    T.it("exposes the runtime pieces a backend needs", function()
        boot("OneLua")
        T.istype(lv1lua.core, "table")
        T.istype(lv1lua.gfx, "table")
        T.istype(lv1lua.current, "table")
        T.istype(lv1lua.timestep, "table")
        T.istype(lv1lua.load, "function")
        T.istype(lv1lua.core.step, "function")
    end)

    T.it("keeps the legacy __mathRound alias pointing at the shared helper", function()
        boot("OneLua")
        T.eq(__mathRound, lv1lua.util.round)
    end)
end)

io.write("\n=== global boundary (T7.3) ===\n")
return T.summary()
